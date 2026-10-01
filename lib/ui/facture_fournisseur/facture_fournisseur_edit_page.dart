import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:fes_distribution/ui/common/fournisseur_field.dart';
import 'package:fes_distribution/ui/common/linked_document_picker_dialog.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/new_tiers_dialog.dart';
import 'package:fes_distribution/ui/common/product_search_card.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Facture fournisseur. [fromBrId] pre-fills a new facture from one BR
/// (Peinture "BR → Facture").
class FactureFournisseurEditPage extends ConsumerStatefulWidget {
  const FactureFournisseurEditPage({super.key, this.factureId, this.fromBrId});

  final int? factureId;
  final int? fromBrId;

  @override
  ConsumerState<FactureFournisseurEditPage> createState() =>
      _FactureFournisseurEditPageState();
}

class _FactureFournisseurEditPageState
    extends ConsumerState<FactureFournisseurEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  DateTime _date = DateTime.now();
  DateTime _dateEcheance = DateTime.now().add(const Duration(days: 30));
  bool _estPayee = false;
  final _noteController = TextEditingController();
  final _remiseController = TextEditingController(text: '0');
  int? _fournisseurId;

  List<Tier> _fournisseurs = [];
  List<Produit> _produits = [];
  List<DocumentLine> _lines = [];
  List<LinkedDocument> _brs = [];

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
    super.dispose();
  }

  double get _remiseGlobale => parseQty(_remiseController.text);

  DocumentTotals get _totals =>
      DocumentTotals.fromLines(_lines, remiseGlobale: _remiseGlobale);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tiers = ref.read(tiersServiceProvider);
      final factures = ref.read(factureFournisseurServiceProvider);
      final fournisseurs = await tiers.listActiveFournisseurs();
      final produits = await ref.read(produitServiceProvider).listActive();

      int? fournisseurId = fournisseurs.isNotEmpty ? fournisseurs.first.id : null;
      if (!_isNew) {
        final doc = await factures.getById(widget.factureId!);
        if (doc == null) throw StateError('Facture fournisseur introuvable.');
        final f = doc.facture;
        fournisseurId = f.fournisseurId;
        _numero = f.numero;
        _date = f.date;
        _dateEcheance = f.dateEcheance;
        _estPayee = f.estPayee;
        _remiseController.text = formatInput(f.remiseGlobale);
        _noteController.text = f.note;
        _lines = doc.lines;
        _brs = doc.brs;
      } else if (widget.fromBrId != null) {
        final br =
            await ref.read(bonReceptionServiceProvider).getById(widget.fromBrId!);
        final linked = await factures.getBr(widget.fromBrId!);
        if (br == null || linked == null) {
          throw StateError('Bon de réception introuvable.');
        }
        if (br.factureNumero != null) {
          throw StateError('${br.br.numero} est déjà facturé (${br.factureNumero}).');
        }
        fournisseurId = br.br.fournisseurId;
        _lines = await factures.loadBrLines(widget.fromBrId!);
        _brs = [linked];
      }

      if (fournisseurId != null && !fournisseurs.any((f) => f.id == fournisseurId)) {
        final f = await tiers.getById(fournisseurId);
        if (f != null) fournisseurs.add(f);
      }
      _fournisseurs = fournisseurs;
      _fournisseurId = fournisseurId;
      _produits = produits;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(
        context,
        title: context.s.menuFacturesFournisseur,
        message: '$e',
      );
      if (mounted) context.pop();
    }
  }

  void _addProduct(Produit p) {
    setState(() {
      final i = _lines.indexWhere(
        (l) => l.produitId == p.id && l.bonReceptionId == null,
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

  Future<void> _pickBrs() async {
    final s = context.s;
    if (_fournisseurId == null) {
      await showErrorDialog(context, title: s.addBrs, message: s.errSelectFournisseur);
      return;
    }
    final linkedIds = _brs.map((b) => b.id).toSet();
    final available = (await ref
            .read(factureFournisseurServiceProvider)
            .availableBrsForFournisseur(_fournisseurId!))
        .where((b) => !linkedIds.contains(b.id))
        .toList();
    if (!mounted) return;
    if (available.isEmpty) {
      await showErrorDialog(context, title: s.addBrs, message: s.noAvailableBrs);
      return;
    }
    final picked = await showLinkedDocumentPicker(
      context,
      title: s.addBrs,
      documents: available,
    );
    if (picked == null || picked.isEmpty) return;

    final factures = ref.read(factureFournisseurServiceProvider);
    final newLines = <DocumentLine>[];
    for (final br in picked) {
      newLines.addAll(await factures.loadBrLines(br.id));
    }
    if (!mounted) return;
    setState(() {
      _brs = [..._brs, ...picked]..sort((a, b) => a.date.compareTo(b.date));
      _lines = [..._lines, ...newLines];
    });
  }

  void _removeBr(LinkedDocument br) {
    setState(() {
      _brs = _brs.where((b) => b.id != br.id).toList();
      _lines = _lines.where((l) => l.bonReceptionId != br.id).toList();
    });
  }

  Future<void> _save() async {
    final s = context.s;
    final title = s.menuFacturesFournisseur;
    final remise = _remiseGlobale;
    String? error;
    if (_fournisseurId == null) {
      error = s.errSelectFournisseur;
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
      final id = await ref.read(factureFournisseurServiceProvider).save(
            id: widget.factureId,
            fournisseurId: _fournisseurId!,
            date: _date,
            dateEcheance: _dateEcheance,
            estPayee: _estPayee,
            remiseGlobale: remise,
            note: _noteController.text,
            lines: _lines,
            brIds: _brs.map((b) => b.id).toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.factureFournisseurSaved)));
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final title = context.s.menuFacturesFournisseur;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(factureFournisseurServiceProvider).delete(widget.factureId!);
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
        title: Text(_isNew ? s.factureFournisseurNew : _numero),
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
                _buildBrs(context),
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
              locked: _brs.isNotEmpty,
              lockedHelper: s.fournisseurLockedByBr,
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

  Widget _buildBrs(BuildContext context) {
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
                  child: Text(s.linkedBrs, style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: _pickBrs,
                  icon: const Icon(Icons.add),
                  label: Text(s.addBrs),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_brs.isEmpty)
              Text(s.noLinkedBr, style: TextStyle(color: AppColors.muted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final br in _brs)
                    InputChip(
                      avatar: const Icon(Icons.move_to_inbox_outlined, size: 18),
                      label: Text(
                        '${br.numero} · ${dateFormat.format(br.date)} · ${formatMoney(br.totalTtc)}',
                      ),
                      deleteButtonTooltipMessage: s.actionDelete,
                      onDeleted: () => _removeBr(br),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(BuildContext context) {
    final s = context.s;
    return DocumentTotalsCard(
      totals: _totals,
      leading: SizedBox(
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
      extra: const [],
    );
  }
}
