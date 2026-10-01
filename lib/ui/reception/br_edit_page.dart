import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/document_paiement.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/common/document_totals_card.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/fournisseur_field.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/new_tiers_dialog.dart';
import 'package:fes_distribution/ui/common/paiement_dialog.dart';
import 'package:fes_distribution/ui/common/product_search_card.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Bon de réception: goods from a supplier enter the default depot.
class BrEditPage extends ConsumerStatefulWidget {
  const BrEditPage({super.key, this.brId});

  final int? brId;

  @override
  ConsumerState<BrEditPage> createState() => _BrEditPageState();
}

class _BrEditPageState extends ConsumerState<BrEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  String? _factureNumero;
  String _depotNom = '';
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();
  int? _fournisseurId;

  List<Tier> _fournisseurs = [];
  List<Produit> _produits = [];
  List<DocumentLine> _lines = [];
  List<DocumentPaiement> _paiements = [];

  bool get _isNew => widget.brId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DocumentTotals get _totals => DocumentTotals.fromLines(_lines);

  double get _totalPaye => _paiements.fold(0, (s, p) => s + p.montant);

  double get _reste {
    final r = _totals.totalTtc - _totalPaye;
    return r > 0 ? r : 0;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tiers = ref.read(tiersServiceProvider);
      final fournisseurs = await tiers.listActiveFournisseurs();
      final produits = await ref.read(produitServiceProvider).listActive();
      final depot =
          await ref.read(stockLocationServiceProvider).getOrCreateDefaultDepot();

      int? fournisseurId = fournisseurs.isNotEmpty ? fournisseurs.first.id : null;
      if (!_isNew) {
        final doc = await ref.read(bonReceptionServiceProvider).getById(widget.brId!);
        if (doc == null) throw StateError('Bon de réception introuvable.');
        fournisseurId = doc.br.fournisseurId;
        _numero = doc.br.numero;
        _date = doc.br.date;
        _noteController.text = doc.br.note;
        _factureNumero = doc.factureNumero;
        _lines = doc.lines;
        _paiements = doc.paiements;
      }
      if (fournisseurId != null && !fournisseurs.any((f) => f.id == fournisseurId)) {
        final f = await tiers.getById(fournisseurId);
        if (f != null) fournisseurs.add(f);
      }
      _fournisseurs = fournisseurs;
      _fournisseurId = fournisseurId;
      _produits = produits;
      _depotNom = depot.nom;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: context.s.menuBr, message: '$e');
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

  Future<void> _addPaiement() async {
    final paiement = await showPaiementDialog(context, suggested: _reste);
    if (paiement == null || !mounted) return;
    final s = context.s;
    final total = _totalPaye + paiement.montant;
    if (DocumentTotals.paymentsExceedTtc(_totals.totalTtc, total)) {
      await showErrorDialog(
        context,
        title: s.paiements,
        message: s.errPaymentsExceed(
          formatMoney(total),
          formatMoney(_totals.totalTtc),
        ),
      );
      return;
    }
    setState(() => _paiements = [paiement, ..._paiements]);
  }

  Future<void> _save() async {
    final s = context.s;
    final title = s.menuBr;
    String? error;
    if (_fournisseurId == null) {
      error = s.errSelectFournisseur;
    } else if (_lines.every((l) => l.produitId <= 0 || l.quantite <= 0)) {
      error = s.errNoLines;
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
      final id = await ref.read(bonReceptionServiceProvider).save(
            id: widget.brId,
            fournisseurId: _fournisseurId!,
            date: _date,
            note: _noteController.text,
            lines: _lines,
            paiements: _paiements,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.brSaved)));
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _invoice() async {
    final factureId = await context
        .push<int>('/achats/factures-fournisseur/new?br=${widget.brId}');
    if (factureId != null && mounted) context.go('/achats/factures-fournisseur');
  }

  Future<void> _delete() async {
    final title = context.s.menuBr;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(bonReceptionServiceProvider).delete(widget.brId!);
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
        title: Text(_isNew ? s.brNew : _numero),
        actions: [
          if (!_isNew && _factureNumero == null && !_loading)
            IconButton(
              tooltip: s.actionInvoice,
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: _saving ? null : _invoice,
            ),
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
                if (_fournisseurs.isEmpty) _banner(s.noFournisseur),
                if (_factureNumero != null) _banner(s.blInvoiced(_factureNumero!)),
                _buildHeader(context),
                const SizedBox(height: 16),
                ProductSearchCard(produits: _produits, onSelected: _addProduct),
                const SizedBox(height: 16),
                DocumentLinesTable(
                  lines: _lines,
                  editablePrice: true,
                  onChanged: (i, line) => setState(() => _lines[i] = line),
                  onRemoveAt: (i) => setState(() => _lines.removeAt(i)),
                ),
                const SizedBox(height: 16),
                DocumentTotalsCard(
                  totals: _totals,
                  extra: [
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
                const Icon(Icons.move_to_inbox_outlined, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.brFlow(_depotNom),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  child: Text(
                    s.paiements,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
                      if (_paiements[i].reference.isNotEmpty)
                        _paiements[i].reference,
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
