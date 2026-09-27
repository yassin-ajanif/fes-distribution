import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/linked_bl.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/new_client_dialog.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Facture client. [fromBlId] pre-fills a new facture from one BL
/// (Peinture "BL → Facture").
class FactureEditPage extends ConsumerStatefulWidget {
  const FactureEditPage({super.key, this.factureId, this.fromBlId});

  final int? factureId;
  final int? fromBlId;

  @override
  ConsumerState<FactureEditPage> createState() => _FactureEditPageState();
}

class _FactureEditPageState extends ConsumerState<FactureEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  DateTime _date = DateTime.now();
  DateTime _dateEcheance = DateTime.now().add(const Duration(days: 30));
  bool _estPayee = false;
  final _noteController = TextEditingController();
  final _remiseController = TextEditingController(text: '0');
  final _bcRefController = TextEditingController();
  int? _clientId;

  List<Tier> _clients = [];
  List<Produit> _produits = [];
  List<DocumentLine> _lines = [];
  List<LinkedBl> _bls = [];

  bool get _isNew => widget.factureId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _remiseController.dispose();
    _bcRefController.dispose();
    super.dispose();
  }

  double get _remiseGlobale => parseQty(_remiseController.text);

  DocumentTotals get _totals =>
      DocumentTotals.fromLines(_lines, remiseGlobale: _remiseGlobale);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tiers = ref.read(tiersServiceProvider);
      final factures = ref.read(factureServiceProvider);
      final clients = await tiers.listActiveClients();
      final produits = await ref.read(produitServiceProvider).listActive();

      int? clientId = clients.isNotEmpty ? clients.first.id : null;
      if (!_isNew) {
        final doc = await factures.getById(widget.factureId!);
        if (doc == null) throw StateError('Facture introuvable.');
        final f = doc.facture;
        clientId = f.clientId;
        _numero = f.numero;
        _date = f.date;
        _dateEcheance = f.dateEcheance;
        _estPayee = f.estPayee;
        _remiseController.text = formatInput(f.remiseGlobale);
        _bcRefController.text = f.bonCommandeReference;
        _noteController.text = f.note;
        _lines = doc.lines;
        _bls = doc.bls;
      } else if (widget.fromBlId != null) {
        final bl =
            await ref.read(bonLivraisonServiceProvider).getById(widget.fromBlId!);
        final linked = await factures.getBl(widget.fromBlId!);
        if (bl == null || linked == null) {
          throw StateError('Bon de livraison introuvable.');
        }
        if (bl.factureNumero != null) {
          throw StateError('${bl.bl.numero} est déjà facturé (${bl.factureNumero}).');
        }
        clientId = bl.bl.clientId;
        _lines = await factures.loadBlLines(widget.fromBlId!);
        _bls = [linked];
      }

      if (clientId != null && !clients.any((c) => c.id == clientId)) {
        final client = await tiers.getById(clientId);
        if (client != null) clients.add(client);
      }
      _clients = clients;
      _clientId = clientId;
      _produits = produits;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: context.s.menuFactures, message: '$e');
      if (mounted) context.pop();
    }
  }

  void _addProduct(Produit p) {
    setState(() {
      final i = _lines.indexWhere(
        (l) => l.produitId == p.id && l.bonLivraisonId == null,
      );
      if (i >= 0) {
        _lines[i] = _lines[i].copyWith(quantite: _lines[i].quantite + 1);
      } else {
        _lines.add(
          DocumentLine(
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
    final created = await showNewClientDialog(context);
    if (created == null || !mounted) return;
    setState(() {
      _clients = [..._clients, created]
        ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      _clientId = created.id;
    });
  }

  Future<void> _pickBls() async {
    final s = context.s;
    if (_clientId == null) {
      await showErrorDialog(context, title: s.addBls, message: s.errSelectClient);
      return;
    }
    final linkedIds = _bls.map((b) => b.id).toSet();
    final available = (await ref
            .read(factureServiceProvider)
            .availableBlsForClient(_clientId!))
        .where((b) => !linkedIds.contains(b.id))
        .toList();
    if (!mounted) return;
    if (available.isEmpty) {
      await showErrorDialog(context, title: s.addBls, message: s.noAvailableBls);
      return;
    }
    final picked = await showDialog<List<LinkedBl>>(
      context: context,
      builder: (_) => _BlPickerDialog(bls: available),
    );
    if (picked == null || picked.isEmpty) return;

    final factures = ref.read(factureServiceProvider);
    final newLines = <DocumentLine>[];
    for (final bl in picked) {
      newLines.addAll(await factures.loadBlLines(bl.id));
    }
    if (!mounted) return;
    setState(() {
      _bls = [..._bls, ...picked]..sort((a, b) => a.date.compareTo(b.date));
      _lines = [..._lines, ...newLines];
    });
  }

  void _removeBl(LinkedBl bl) {
    setState(() {
      _bls = _bls.where((b) => b.id != bl.id).toList();
      _lines = _lines.where((l) => l.bonLivraisonId != bl.id).toList();
    });
  }

  Future<void> _save() async {
    final s = context.s;
    final title = s.menuFactures;
    final remise = _remiseGlobale;
    String? error;
    if (_clientId == null) {
      error = s.errSelectClient;
    } else if (_lines.every((l) => l.produitId <= 0 || l.quantite <= 0)) {
      error = s.errNoLines;
    } else if (remise < 0 || remise > 100) {
      error = s.errRemiseGlobale;
    } else if (DocumentTotals.isEffectivelyZero(_totals.totalTtc)) {
      error = s.errZeroTtc;
    }
    if (error != null) {
      await showErrorDialog(context, title: title, message: error);
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(factureServiceProvider).save(
            id: widget.factureId,
            clientId: _clientId!,
            date: _date,
            dateEcheance: _dateEcheance,
            estPayee: _estPayee,
            remiseGlobale: remise,
            bonCommandeReference: _bcRefController.text,
            note: _noteController.text,
            lines: _lines,
            blIds: _bls.map((b) => b.id).toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.factureSaved)));
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final title = context.s.menuFactures;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(factureServiceProvider).delete(widget.factureId!);
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
        title: Text(_isNew ? s.factureNew : _numero),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: s.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          AppBarSaveButton(
            onPressed: _loading ? null : _save,
            saving: _saving,
          ),
        ],
      ),
      body: _loading
          ? LoadingView(message: s.loading)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_clients.isEmpty)
                  Card(
                    color: AppColors.brandSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.noClient),
                    ),
                  ),
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildBls(context),
                const SizedBox(height: 16),
                _buildAddProduct(context),
                const SizedBox(height: 16),
                DocumentLinesTable(
                  lines: _lines,
                  onChanged: (i, line) => setState(() => _lines[i] = line),
                  onRemoveAt: (i) => setState(() => _lines.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _buildTotals(context),
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

  Widget _buildHeader(BuildContext context) {
    final s = context.s;
    final clientLocked = _bls.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('client-$_clientId-${_clients.length}-$clientLocked'),
                    initialValue: _clientId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: s.fieldClient,
                      prefixIcon: const Icon(Icons.person_outline),
                      helperText: clientLocked ? s.clientLockedByBl : null,
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
                    onChanged: clientLocked
                        ? null
                        : (v) => setState(() => _clientId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: s.newClient,
                  icon: const Icon(Icons.person_add_alt_1),
                  onPressed: clientLocked ? null : _newClient,
                ),
              ],
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
            const SizedBox(height: 12),
            TextField(
              controller: _bcRefController,
              decoration: InputDecoration(
                labelText: s.fieldBonCommandeRef,
                prefixIcon: const Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.fieldEstPayee),
              value: _estPayee,
              onChanged: (v) => setState(() => _estPayee = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBls(BuildContext context) {
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
                  child: Text(s.linkedBls, style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: _pickBls,
                  icon: const Icon(Icons.add),
                  label: Text(s.addBls),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_bls.isEmpty)
              Text(s.noLinkedBl, style: TextStyle(color: AppColors.muted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bl in _bls)
                    InputChip(
                      avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text(
                        '${bl.numero} · ${dateFormat.format(bl.date)} · ${formatMoney(bl.totalTtc)}',
                      ),
                      deleteButtonTooltipMessage: s.actionDelete,
                      onDeleted: () => _removeBl(bl),
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
              displayStringForOption: (p) => '${p.reference} — ${p.designation}',
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlPickerDialog extends StatefulWidget {
  const _BlPickerDialog({required this.bls});

  final List<LinkedBl> bls;

  @override
  State<_BlPickerDialog> createState() => _BlPickerDialogState();
}

class _BlPickerDialogState extends State<_BlPickerDialog> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.addBls),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final bl in widget.bls)
              CheckboxListTile(
                value: _selected.contains(bl.id),
                title: Text(bl.numero),
                subtitle: Text(
                  '${dateFormat.format(bl.date)} · ${formatMoney(bl.totalTtc)}',
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(bl.id);
                  } else {
                    _selected.remove(bl.id);
                  }
                }),
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    widget.bls.where((b) => _selected.contains(b.id)).toList(),
                  ),
          child: Text(s.actionConfirm),
        ),
      ],
    );
  }
}
