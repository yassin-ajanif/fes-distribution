import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/linked_document.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/common/document_totals_card.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/new_tiers_dialog.dart';
import 'package:fes_distribution/ui/common/product_image.dart';
import 'package:fes_distribution/ui/common/product_search_card.dart';
import 'package:fes_distribution/ui/common/tiers_label.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Avoir client, optionally crediting a facture. [fromFactureId] pre-fills a
/// new avoir from that facture (Peinture "Facture → Avoir"). With "retour de
/// marchandise" the goods go back into the vendeur's car.
class AvoirEditPage extends ConsumerStatefulWidget {
  const AvoirEditPage({super.key, this.avoirId, this.fromFactureId});

  final int? avoirId;
  final int? fromFactureId;

  @override
  ConsumerState<AvoirEditPage> createState() => _AvoirEditPageState();
}

class _AvoirEditPageState extends ConsumerState<AvoirEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  DateTime _date = DateTime.now();
  bool _retourMarchandise = true;
  final _motifController = TextEditingController();
  int? _clientId;
  int? _factureId;
  int? _vendeurId;

  List<Tier> _clients = [];
  List<User> _vendeurs = [];
  List<LinkedDocument> _factures = [];
  List<Produit> _produits = [];
  List<DocumentLine> _lines = [];

  /// TTC still creditable on [_factureId], excluding this avoir.
  double? _reste;

  bool get _isNew => widget.avoirId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  DocumentTotals get _totals => DocumentTotals.fromLines(_lines);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tiers = ref.read(tiersServiceProvider);
      final avoirs = ref.read(avoirServiceProvider);
      final clients = await tiers.listActiveClients();
      final vendeurs = await ref.read(userServiceProvider).listActiveVendeurs();
      final produits = await ref.read(produitServiceProvider).listActive();

      int? clientId = clients.isNotEmpty ? clients.first.id : null;
      int? vendeurId = vendeurs.isNotEmpty ? vendeurs.first.id : null;
      if (!_isNew) {
        final doc = await avoirs.getById(widget.avoirId!);
        if (doc == null) throw StateError('Avoir introuvable.');
        final a = doc.avoir;
        clientId = a.clientId;
        _factureId = a.factureId;
        _numero = a.numero;
        _date = a.date;
        _retourMarchandise = a.retourMarchandise;
        _motifController.text = a.motif;
        _lines = doc.lines;
        vendeurId = doc.vendeurId ?? vendeurId;
      } else if (widget.fromFactureId != null) {
        final facture = await avoirs.getFacture(widget.fromFactureId!);
        if (facture == null) throw StateError('Facture introuvable.');
        clientId = facture.clientId;
        _factureId = facture.id;
        _lines = await avoirs.loadFactureLines(facture.id);
        vendeurId = await avoirs.vendeurForFacture(facture.id) ?? vendeurId;
      }

      if (clientId != null && !clients.any((c) => c.id == clientId)) {
        final client = await tiers.getById(clientId);
        if (client != null) clients.add(client);
      }
      if (vendeurId != null && !vendeurs.any((u) => u.id == vendeurId)) {
        final user = await ref.read(userServiceProvider).getById(vendeurId);
        if (user != null) vendeurs.add(user);
      }
      _clients = clients;
      _vendeurs = vendeurs;
      _clientId = clientId;
      _vendeurId = vendeurId;
      _produits = produits;
      await _refreshFactures();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(
        context,
        title: context.s.menuAvoirs,
        message: '$e',
      );
      if (mounted) context.pop();
    }
  }

  Future<void> _refreshFactures() async {
    final avoirs = ref.read(avoirServiceProvider);
    _factures = _clientId == null
        ? []
        : await avoirs.facturesForClient(_clientId!);
    _reste = _factureId == null
        ? null
        : await avoirs.remainingOnFacture(
            _factureId!,
            excludeAvoirId: widget.avoirId,
          );
  }

  Future<void> _onClientChanged(int? id) async {
    setState(() {
      _clientId = id;
      _factureId = null;
    });
    await _refreshFactures();
    if (mounted) setState(() {});
  }

  Future<void> _onFactureChanged(int? id) async {
    final avoirs = ref.read(avoirServiceProvider);
    setState(() => _factureId = id);
    if (id != null) {
      final hasLines = _lines.any((l) => l.produitId > 0);
      final replace =
          !hasLines ||
          await showConfirmDialog(
            context,
            title: context.s.menuAvoirs,
            message: context.s.replaceLinesWithFacture,
          );
      if (replace) {
        final lines = await avoirs.loadFactureLines(id);
        final vendeurId = await avoirs.vendeurForFacture(id);
        _lines = lines;
        if (vendeurId != null && _vendeurs.any((u) => u.id == vendeurId)) {
          _vendeurId = vendeurId;
        }
      }
    }
    await _refreshFactures();
    if (mounted) setState(() {});
  }

  void _addProduct(Produit p) {
    setState(() {
      final i = _lines.indexWhere((l) => l.produitId == p.id);
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
    });
    await _onClientChanged(created.id);
  }

  Future<void> _save() async {
    final s = context.s;
    final title = s.menuAvoirs;
    String? error;
    if (_clientId == null) {
      error = s.errSelectClient;
    } else if (_retourMarchandise && _vendeurId == null) {
      error = s.errSelectVendeur;
    } else if (_lines.every((l) => l.produitId <= 0 || l.quantite <= 0)) {
      error = s.errNoLines;
    } else if (DocumentTotals.isEffectivelyZero(_totals.totalTtc)) {
      error = s.errZeroTtc;
    }
    if (error != null) {
      await showErrorDialog(context, title: title, message: error);
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref
          .read(avoirServiceProvider)
          .save(
            id: widget.avoirId,
            clientId: _clientId!,
            factureId: _factureId,
            date: _date,
            motif: _motifController.text,
            retourMarchandise: _retourMarchandise,
            vendeurId: _retourMarchandise ? _vendeurId : null,
            lines: _lines,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.avoirSaved)));
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final title = context.s.menuAvoirs;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(avoirServiceProvider).delete(widget.avoirId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _banner(String text) => Card(
    color: AppColors.brandSoft,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
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
        title: Text(_isNew ? s.avoirNew : _numero),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: s.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          AppBarSaveButton(onPressed: _loading ? null : _save, saving: _saving),
        ],
      ),
      body: _loading
          ? LoadingView(message: s.loading)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_clients.isEmpty) _banner(s.noClient),
                if (_retourMarchandise && _vendeurs.isEmpty)
                  _banner(s.noActiveVendeur),
                _buildHeader(context),
                const SizedBox(height: 16),
                ProductSearchCard(produits: _produits, onSelected: _addProduct),
                const SizedBox(height: 16),
                DocumentLinesTable(
                  lines: _lines,
                  editablePrice: true,
                  images: productImagesById(_produits),
                  onChanged: (i, line) => setState(() => _lines[i] = line),
                  onRemoveAt: (i) => setState(() => _lines.removeAt(i)),
                ),
                const SizedBox(height: 16),
                DocumentTotalsCard(totals: _totals),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _motifController,
                      decoration: InputDecoration(labelText: s.fieldMotif),
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
    final clientLocked = _factureId != null;
    final reste = _reste;
    final overReste =
        reste != null &&
        _totals.totalTtc > reste + DocumentTotals.paiementTtcTolerance;
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
                    key: ValueKey(
                      'client-$_clientId-${_clients.length}-$clientLocked',
                    ),
                    initialValue: _clientId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: s.fieldClient,
                      prefixIcon: const Icon(Icons.person_outline),
                      helperText: clientLocked ? s.clientLockedByFacture : null,
                    ),
                    items: [
                      for (final c in _clients)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            tiersLabel(c),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: clientLocked ? null : _onClientChanged,
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
            DropdownButtonFormField<int?>(
              key: ValueKey(
                'facture-$_clientId-$_factureId-${_factures.length}',
              ),
              initialValue: _factureId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.fieldFactureOptional,
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                helperText: reste == null
                    ? null
                    : s.resteSurFacture(formatMoney(reste)),
                helperStyle: overReste
                    ? TextStyle(color: AppColors.danger)
                    : null,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(s.noFactureLinked),
                ),
                for (final f in _factures)
                  DropdownMenuItem<int?>(
                    value: f.id,
                    child: Text(
                      '${f.numero} · ${dateFormat.format(f.date)} · ${formatMoney(f.totalTtc)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _onFactureChanged,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
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
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.fieldRetourMarchandise),
              subtitle: Text(
                _retourMarchandise
                    ? s.retourVendeurHint
                    : s.noRetourMarchandiseHint,
              ),
              value: _retourMarchandise,
              onChanged: (v) => setState(() => _retourMarchandise = v),
            ),
            if (_retourMarchandise)
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
                    DropdownMenuItem(
                      value: u.id,
                      child: Text(
                        vendeurLabel(u),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _vendeurId = v),
              ),
          ],
        ),
      ),
    );
  }
}
