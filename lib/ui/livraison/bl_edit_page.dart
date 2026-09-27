import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/enums/mode_paiement.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/bon_livraison_paiement.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/l10n/app_strings.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/personnel/widgets/document_lines_table.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

extension ModePaiementLabel on ModePaiement {
  String label(AppStrings s) => switch (this) {
        ModePaiement.credit => s.modeCredit,
        ModePaiement.cheque => s.modeCheque,
        ModePaiement.especes => s.modeEspeces,
        ModePaiement.tpe => s.modeTpe,
        ModePaiement.virement => s.modeVirement,
        ModePaiement.effet => s.modeEffet,
      };
}

class BlEditPage extends ConsumerStatefulWidget {
  const BlEditPage({super.key, this.blId});

  final int? blId;

  @override
  ConsumerState<BlEditPage> createState() => _BlEditPageState();
}

class _BlEditPageState extends ConsumerState<BlEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  DateTime _date = DateTime.now();
  DateTime _dateEcheance = DateTime.now().add(const Duration(days: 30));
  final _noteController = TextEditingController();
  final _remiseController = TextEditingController(text: '0');
  int? _clientId;
  int? _vendeurId;

  List<Tier> _clients = [];
  List<User> _vendeurs = [];
  List<Produit> _produits = [];
  List<PersonnelDocumentLine> _lines = [];
  List<BonLivraisonPaiement> _paiements = [];

  /// Stock in the selected vendeur's car, including what this saved BL
  /// already took out of it.
  Map<int, double> _available = {};
  final Map<int, int> _carByUser = {};
  int? _savedVendeurId;
  Map<int, double> _savedQty = {};

  bool get _isNew => widget.blId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _remiseController.dispose();
    super.dispose();
  }

  double get _remiseGlobale => parseQty(_remiseController.text);

  DocumentTotals get _totals =>
      DocumentTotals.fromLines(_lines, remiseGlobale: _remiseGlobale);

  double get _totalPaye => _paiements.fold(0, (s, p) => s + p.montant);

  double get _reste {
    final r = _totals.totalTtc - _totalPaye;
    return r > 0 ? r : 0;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = ref.read(userServiceProvider);
      final clients = await ref.read(tiersServiceProvider).listActiveClients();
      final vendeurs = await users.listActiveVendeurs();
      final produits = await ref.read(produitServiceProvider).listActive();

      if (_isNew) {
        _numero = '';
        _clientId = clients.isNotEmpty ? clients.first.id : null;
        _vendeurId = vendeurs.isNotEmpty ? vendeurs.first.id : null;
      } else {
        final doc = await ref.read(bonLivraisonServiceProvider).getById(widget.blId!);
        if (doc == null) throw StateError('Bon de livraison introuvable.');
        final bl = doc.bl;
        if (!clients.any((c) => c.id == bl.clientId)) {
          final client = await ref.read(tiersServiceProvider).getById(bl.clientId);
          if (client != null) clients.add(client);
        }
        if (bl.vendeurId != null && !vendeurs.any((u) => u.id == bl.vendeurId)) {
          final assigned = await users.getById(bl.vendeurId!);
          if (assigned != null) vendeurs.add(assigned);
        }
        _numero = bl.numero;
        _date = bl.date;
        _dateEcheance = bl.dateEcheance;
        _clientId = bl.clientId;
        _vendeurId = vendeurs.any((u) => u.id == bl.vendeurId) ? bl.vendeurId : null;
        _remiseController.text = _formatInput(bl.remiseGlobale);
        _noteController.text = bl.note;
        _lines = doc.lines;
        _paiements = doc.paiements;
        _savedVendeurId = bl.vendeurId;
        _savedQty = {};
        for (final l in doc.lines) {
          _savedQty[l.produitId] = (_savedQty[l.produitId] ?? 0) + l.quantite;
        }
      }
      _clients = clients;
      _vendeurs = vendeurs;
      _produits = produits;
      await _refreshAvailable();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: context.s.menuBl, message: '$e');
      if (mounted) context.pop();
    }
  }

  Future<int?> _carLocationId(int userId) async {
    final cached = _carByUser[userId];
    if (cached != null) return cached;
    final user = await ref.read(userServiceProvider).getById(userId);
    if (user == null) return null;
    final car =
        await ref.read(stockLocationServiceProvider).getOrCreateVirtualForUser(user);
    return _carByUser[userId] = car.id;
  }

  Future<void> _refreshAvailable() async {
    final carId = _vendeurId == null ? null : await _carLocationId(_vendeurId!);
    if (carId == null) {
      _available = {};
      return;
    }
    final stock =
        await ref.read(stockBalanceServiceProvider).getAllStocksAtLocation(carId);
    if (_vendeurId == _savedVendeurId) {
      for (final e in _savedQty.entries) {
        stock[e.key] = (stock[e.key] ?? 0) + e.value;
      }
    }
    _available = stock;
  }

  Future<void> _onVendeurChanged(int id) async {
    setState(() => _vendeurId = id);
    await _refreshAvailable();
    if (mounted) setState(() {});
  }

  void _addProduct(Produit p) {
    setState(() {
      final i = _lines.indexWhere((l) => l.produitId == p.id);
      if (i >= 0) {
        _lines[i] = _lines[i].copyWith(quantite: _lines[i].quantite + 1);
      } else {
        _lines.add(
          PersonnelDocumentLine(
            produitId: p.id,
            reference: p.reference,
            designation: p.designation,
            quantite: 1,
            prixUnitaireHt: p.prixVenteHT,
            tauxTva: p.tauxTVA,
          ),
        );
      }
    });
  }

  Future<void> _newClient() async {
    final s = context.s;
    final created = await showDialog<Tier>(
      context: context,
      builder: (_) => const _NewClientDialog(),
    );
    if (created == null || !mounted) return;
    setState(() {
      _clients = [..._clients, created]
        ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      _clientId = created.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${s.newClient} : ${created.nom}')),
    );
  }

  Future<void> _addPaiement() async {
    final paiement = await showDialog<BonLivraisonPaiement>(
      context: context,
      builder: (_) => _PaiementDialog(suggested: _reste),
    );
    if (paiement == null || !mounted) return;
    final s = context.s;
    final total = _totalPaye + paiement.montant;
    if (DocumentTotals.paymentsExceedTtc(_totals.totalTtc, total)) {
      await showErrorDialog(
        context,
        title: s.paiements,
        message: s.errPaymentsExceed(formatMoney(total), formatMoney(_totals.totalTtc)),
      );
      return;
    }
    setState(() => _paiements = [paiement, ..._paiements]);
  }

  Future<void> _save() async {
    final s = context.s;
    final title = s.menuBl;
    final remise = _remiseGlobale;
    String? error;
    if (_clientId == null) {
      error = s.errSelectClient;
    } else if (_vendeurId == null) {
      error = s.errSelectVendeur;
    } else if (_lines.every((l) => l.produitId <= 0 || l.quantite <= 0)) {
      error = s.errNoLines;
    } else if (remise < 0 || remise > 100) {
      error = s.errRemiseGlobale;
    } else if (DocumentTotals.isEffectivelyZero(_totals.totalTtc)) {
      error = s.errZeroTtc;
    } else if (DocumentTotals.paymentsExceedTtc(_totals.totalTtc, _totalPaye)) {
      error = s.errPaymentsExceed(
        formatMoney(_totalPaye),
        formatMoney(_totals.totalTtc),
      );
    }
    if (error != null) {
      await showErrorDialog(context, title: title, message: error);
      return;
    }

    setState(() => _saving = true);
    try {
      final carId = await _carLocationId(_vendeurId!);
      final shortages =
          await ref.read(stockMovementServiceProvider).getOutboundShortages(
                fromLocationId: carId!,
                desiredOutboundLines: _lines
                    .where((l) => l.produitId > 0 && l.quantite > 0)
                    .map((l) => (produitId: l.produitId, quantite: l.quantite)),
                origineType: StockMovementService.origineTypeBonLivraison,
                origineId: widget.blId,
              );
      if (!mounted) return;
      if (shortages.isNotEmpty) {
        final ok = await showStockShortageDialog(
          context,
          lines: [
            for (final x in shortages)
              s.shortageLine(
                x.reference,
                formatQty(x.requested),
                formatQty(x.available),
              ),
          ],
        );
        if (!ok) return;
      }

      final id = await ref.read(bonLivraisonServiceProvider).save(
            id: widget.blId,
            clientId: _clientId!,
            vendeurId: _vendeurId!,
            date: _date,
            dateEcheance: _dateEcheance,
            remiseGlobale: remise,
            note: _noteController.text,
            lines: _lines,
            paiements: _paiements,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.blSaved)));
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final title = context.s.menuBl;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(bonLivraisonServiceProvider).delete(widget.blId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isNew ? s.blNew : _numero),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: s.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          AppBarSaveButton(
            onPressed: _loading || _vendeurs.isEmpty ? null : _save,
            saving: _saving,
          ),
        ],
      ),
      body: _loading
          ? LoadingView(message: s.loading)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_vendeurs.isEmpty) _banner(s.noActiveVendeur),
                if (_clients.isEmpty) _banner(s.noClient),
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildAddProduct(context),
                const SizedBox(height: 16),
                DocumentLinesTable(
                  lines: _lines,
                  available: _available,
                  onChanged: (i, line) => setState(() => _lines[i] = line),
                  onRemoveAt: (i) => setState(() => _lines.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _buildTotals(context),
                const SizedBox(height: 16),
                _buildPaiements(context),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _noteController,
                      decoration: InputDecoration(labelText: s.note),
                      maxLines: 3,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _banner(String text) => Card(
        color: AppColors.brandSoft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text),
        ),
      );

  Widget _buildHeader(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(s.blFlow, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('client-$_clientId-${_clients.length}'),
                    initialValue: _clientId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: s.fieldClient,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    items: [
                      for (final c in _clients)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.ville.isEmpty ? c.nom : '${c.nom} — ${c.ville}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _clientId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: s.newClient,
                  icon: const Icon(Icons.person_add_alt_1),
                  onPressed: _newClient,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('vendeur-$_vendeurId-${_vendeurs.length}'),
              initialValue: _vendeurId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.fieldVendeur,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              items: [
                for (final u in _vendeurs)
                  DropdownMenuItem(value: u.id, child: Text(u.fullName)),
              ],
              onChanged: (v) {
                if (v != null) _onVendeurChanged(v);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pick(_date);
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('${s.fieldDate} : ${dateFormat.format(_date)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pick(_dateEcheance);
                    if (picked != null) setState(() => _dateEcheance = picked);
                  },
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                    '${s.fieldDateEcheance} : ${dateFormat.format(_dateEcheance)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProduct(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.addProduct, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Autocomplete<Produit>(
              optionsBuilder: (text) {
                final t = text.text.toLowerCase();
                if (t.isEmpty) return _produits.take(20);
                return _produits.where(
                  (p) =>
                      p.reference.toLowerCase().contains(t) ||
                      p.designation.toLowerCase().contains(t) ||
                      (p.codeBarre?.toLowerCase().contains(t) ?? false),
                );
              },
              displayStringForOption: (p) =>
                  '${p.reference} — ${p.designation} (${s.available(formatQty(_available[p.id] ?? 0))})',
              onSelected: _addProduct,
              fieldViewBuilder: (context, controller, focusNode, _) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: s.searchProduct,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onTap: controller.clear,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(BuildContext context) {
    final s = context.s;
    final totals = _totals;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _remiseController,
                decoration: InputDecoration(
                  labelText: s.fieldRemiseGlobale,
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(s.totalHt(formatMoney(totals.totalHt))),
                Text(s.totalTva(formatMoney(totals.totalTva))),
                Text(
                  s.totalTtc(formatMoney(totals.totalTtc)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(s.montantPaye(formatMoney(_totalPaye))),
                Text(
                  s.resteAPayer(formatMoney(_reste)),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _reste > DocumentTotals.paiementTtcTolerance
                        ? AppColors.danger
                        : AppColors.brand,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaiements(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.paiements, style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: _addPaiement,
                  icon: const Icon(Icons.add),
                  label: Text(s.addPaiement),
                ),
              ],
            ),
            if (_paiements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(s.noPaiement, style: TextStyle(color: AppColors.muted)),
              )
            else
              for (var i = 0; i < _paiements.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(formatMoney(_paiements[i].montant)),
                  subtitle: Text(
                    [
                      dateFormat.format(_paiements[i].date),
                      _paiements[i].mode.label(s),
                      if (_paiements[i].reference.isNotEmpty) _paiements[i].reference,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: s.actionDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() => _paiements.removeAt(i)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _formatInput(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _NewClientDialog extends ConsumerStatefulWidget {
  const _NewClientDialog();

  @override
  ConsumerState<_NewClientDialog> createState() => _NewClientDialogState();
}

class _NewClientDialogState extends ConsumerState<_NewClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _ville = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _ville.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = await ref.read(tiersServiceProvider).createClient(
            nom: _nom.text,
            telephone: _telephone.text,
            ville: _ville.text,
          );
      if (mounted) Navigator.of(context).pop(client);
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: context.s.newClient, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.newClient),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nom,
              autofocus: true,
              decoration: InputDecoration(labelText: s.fieldName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telephone,
              decoration: InputDecoration(labelText: s.fieldTelephone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ville,
              decoration: InputDecoration(labelText: s.fieldVille),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(s.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(s.actionSave),
        ),
      ],
    );
  }
}

class _PaiementDialog extends StatefulWidget {
  const _PaiementDialog({required this.suggested});

  final double suggested;

  @override
  State<_PaiementDialog> createState() => _PaiementDialogState();
}

class _PaiementDialogState extends State<_PaiementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _montant = TextEditingController(
    text: widget.suggested > 0 ? widget.suggested.toStringAsFixed(2) : '',
  );
  final _reference = TextEditingController();
  DateTime _date = DateTime.now();
  ModePaiement _mode = ModePaiement.especes;

  @override
  void dispose() {
    _montant.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.addPaiement),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _montant,
              autofocus: true,
              decoration: InputDecoration(labelText: s.fieldMontant),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (v) => parseQty(v ?? '') <= 0 ? s.errAmount : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ModePaiement>(
              initialValue: _mode,
              decoration: InputDecoration(labelText: s.fieldMode),
              items: [
                for (final m in ModePaiement.values)
                  DropdownMenuItem(value: m, child: Text(m.label(s))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _mode = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reference,
              decoration: InputDecoration(labelText: s.fieldReference2),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('${s.fieldDate} : ${dateFormat.format(_date)}'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              BonLivraisonPaiement(
                date: _date,
                montant: parseQty(_montant.text),
                mode: _mode,
                reference: _reference.text,
              ),
            );
          },
          child: Text(s.actionConfirm),
        ),
      ],
    );
  }
}
