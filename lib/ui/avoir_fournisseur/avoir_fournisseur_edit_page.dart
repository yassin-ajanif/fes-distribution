import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/common/document_totals_card.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/fournisseur_field.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/new_tiers_dialog.dart';
import 'package:fes_distribution/ui/common/product_search_card.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Avoir fournisseur. With "retour de marchandise" the goods leave the
/// default depot.
class AvoirFournisseurEditPage extends ConsumerStatefulWidget {
  const AvoirFournisseurEditPage({super.key, this.avoirId});

  final int? avoirId;

  @override
  ConsumerState<AvoirFournisseurEditPage> createState() =>
      _AvoirFournisseurEditPageState();
}

class _AvoirFournisseurEditPageState
    extends ConsumerState<AvoirFournisseurEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  DateTime _date = DateTime.now();
  bool _retourMarchandise = true;
  final _motifController = TextEditingController();
  int? _fournisseurId;
  int? _depotId;
  String _depotNom = '';

  List<Tier> _fournisseurs = [];
  List<Produit> _produits = [];
  List<DocumentLine> _lines = [];

  /// Depot stock, including what this saved avoir already took out of it.
  Map<int, double> _available = {};

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
      final fournisseurs = await tiers.listActiveFournisseurs();
      final produits = await ref.read(produitServiceProvider).listActive();
      final depot =
          await ref.read(stockLocationServiceProvider).getOrCreateDefaultDepot();
      final stock = await ref
          .read(stockBalanceServiceProvider)
          .getAllStocksAtLocation(depot.id);

      int? fournisseurId = fournisseurs.isNotEmpty ? fournisseurs.first.id : null;
      if (!_isNew) {
        final doc =
            await ref.read(avoirFournisseurServiceProvider).getById(widget.avoirId!);
        if (doc == null) throw StateError('Avoir fournisseur introuvable.');
        fournisseurId = doc.avoir.fournisseurId;
        _numero = doc.avoir.numero;
        _date = doc.avoir.date;
        _retourMarchandise = doc.avoir.retourMarchandise;
        _motifController.text = doc.avoir.motif;
        _lines = doc.lines;
        if (doc.avoir.retourMarchandise) {
          for (final l in doc.lines) {
            stock[l.produitId] = (stock[l.produitId] ?? 0) + l.quantite;
          }
        }
      }
      if (fournisseurId != null && !fournisseurs.any((f) => f.id == fournisseurId)) {
        final f = await tiers.getById(fournisseurId);
        if (f != null) fournisseurs.add(f);
      }
      _fournisseurs = fournisseurs;
      _fournisseurId = fournisseurId;
      _produits = produits;
      _depotId = depot.id;
      _depotNom = depot.nom;
      _available = stock;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(
        context,
        title: context.s.menuAvoirsFournisseur,
        message: '$e',
      );
      if (mounted) context.pop();
    }
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
            prixUnitaireHt: p.prixAchatHT,
            tauxTva: p.tauxTVA,
          ),
        );
      }
    });
  }

  Future<void> _newFournisseur() async {
    final created = await showNewFournisseurDialog(context);
    if (created == null || !mounted) return;
    setState(() {
      _fournisseurs = [..._fournisseurs, created]
        ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      _fournisseurId = created.id;
    });
  }

  Future<void> _save() async {
    final s = context.s;
    final title = s.menuAvoirsFournisseur;
    String? error;
    if (_fournisseurId == null) {
      error = s.errSelectFournisseur;
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
      if (_retourMarchandise && _depotId != null) {
        final shortages =
            await ref.read(stockMovementServiceProvider).getOutboundShortages(
                  fromLocationId: _depotId!,
                  desiredOutboundLines: _lines
                      .where((l) => l.produitId > 0 && l.quantite > 0)
                      .map((l) => (produitId: l.produitId, quantite: l.quantite)),
                  origineType: StockMovementService.origineTypeAvoirFournisseur,
                  origineId: widget.avoirId,
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
      }

      final id = await ref.read(avoirFournisseurServiceProvider).save(
            id: widget.avoirId,
            fournisseurId: _fournisseurId!,
            date: _date,
            motif: _motifController.text,
            retourMarchandise: _retourMarchandise,
            lines: _lines,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.avoirFournisseurSaved)));
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final title = context.s.menuAvoirsFournisseur;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(avoirFournisseurServiceProvider).delete(widget.avoirId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isNew ? s.avoirFournisseurNew : _numero),
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
                if (_fournisseurs.isEmpty)
                  Card(
                    color: AppColors.brandSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.noFournisseur),
                    ),
                  ),
                _buildHeader(context),
                const SizedBox(height: 16),
                ProductSearchCard(
                  produits: _produits,
                  onSelected: _addProduct,
                  available: _retourMarchandise ? _available : null,
                ),
                const SizedBox(height: 16),
                DocumentLinesTable(
                  lines: _lines,
                  editablePrice: true,
                  available: _retourMarchandise ? _available : null,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FournisseurField(
              fournisseurs: _fournisseurs,
              value: _fournisseurId,
              onChanged: (v) => setState(() => _fournisseurId = v),
              onCreate: _newFournisseur,
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
                    ? s.retourMarchandiseHint(_depotNom)
                    : s.noRetourMarchandiseHint,
              ),
              value: _retourMarchandise,
              onChanged: (v) => setState(() => _retourMarchandise = v),
            ),
          ],
        ),
      ),
    );
  }
}
