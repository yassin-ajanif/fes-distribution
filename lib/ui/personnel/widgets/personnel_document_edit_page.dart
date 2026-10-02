import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/product_image.dart';
import 'package:fes_distribution/ui/common/product_search_card.dart';
import 'package:fes_distribution/ui/common/tiers_label.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Bon de charge = depot → vendeur car. Bon de décharge = vendeur car → depot.
enum PersonnelDocKind { charge, decharge }

typedef _LoadedDoc = ({
  String numero,
  DateTime date,
  String note,
  int userId,
  int depotId,
  List<DocumentLine> lines,
});

class PersonnelDocumentEditPage extends ConsumerStatefulWidget {
  const PersonnelDocumentEditPage({super.key, required this.kind, this.bonId});

  final PersonnelDocKind kind;
  final int? bonId;

  @override
  ConsumerState<PersonnelDocumentEditPage> createState() =>
      _PersonnelDocumentEditPageState();
}

class _PersonnelDocumentEditPageState
    extends ConsumerState<PersonnelDocumentEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '';
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();
  int? _userId;
  int? _depotId;

  List<User> _vendeurs = [];
  List<StockLocation> _depots = [];
  List<Produit> _produits = [];
  List<DocumentLine> _lines = [];

  /// Stock at the source (depot for charge, vendeur car for décharge),
  /// including what this saved bon already moved out of it.
  Map<int, double> _available = {};
  final Map<int, int> _carByUser = {};
  int? _savedSourceId;
  Map<int, double> _savedQty = {};

  bool get _isCharge => widget.kind == PersonnelDocKind.charge;
  bool get _isNew => widget.bonId == null;
  String get _origineType => _isCharge
      ? StockMovementService.origineTypeBonCharge
      : StockMovementService.origineTypeBonDecharge;

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

  String _title(BuildContext context) {
    final s = context.s;
    if (!_isNew) return _numero;
    return _isCharge ? s.bonChargeNew : s.bonDechargeNew;
  }

  String _docLabel(BuildContext context) =>
      _isCharge ? context.s.menuBonCharge : context.s.menuBonDecharge;

  Future<_LoadedDoc?> _fetch(int id) async {
    if (_isCharge) {
      final d = await ref.read(bonChargeServiceProvider).getById(id);
      if (d == null) return null;
      return (
        numero: d.bon.numero,
        date: d.bon.date,
        note: d.bon.note,
        userId: d.bon.assignedToUserId,
        depotId: d.bon.depotLocationId,
        lines: d.lines,
      );
    }
    final d = await ref.read(bonDechargeServiceProvider).getById(id);
    if (d == null) return null;
    return (
      numero: d.bon.numero,
      date: d.bon.date,
      note: d.bon.note,
      userId: d.bon.assignedToUserId,
      depotId: d.bon.depotLocationId,
      lines: d.lines,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = ref.read(userServiceProvider);
      final vendeurs = await users.listActiveVendeurs();
      final depots = await ref
          .read(stockLocationServiceProvider)
          .getActivePhysicalLocations();
      final produits = await ref.read(produitServiceProvider).listActive();

      _LoadedDoc? doc;
      if (!_isNew) {
        doc = await _fetch(widget.bonId!);
        if (doc == null) throw StateError('Bon introuvable.');
        if (!vendeurs.any((u) => u.id == doc!.userId)) {
          final assigned = await users.getById(doc.userId);
          if (assigned != null) vendeurs.add(assigned);
        }
      }

      _vendeurs = vendeurs;
      _depots = depots;
      _produits = produits;
      if (doc == null) {
        _numero = '';
        _date = DateTime.now();
        _noteController.clear();
        _userId = vendeurs.isNotEmpty ? vendeurs.first.id : null;
        _depotId = depots.isNotEmpty ? depots.first.id : null;
        _lines = [];
        _savedSourceId = null;
        _savedQty = {};
      } else {
        _numero = doc.numero;
        _date = doc.date;
        _noteController.text = doc.note;
        _userId = doc.userId;
        _depotId = depots.any((d) => d.id == doc!.depotId) ? doc.depotId : null;
        _lines = doc.lines;
        _savedSourceId = await _sourceLocationId(
          userId: doc.userId,
          depotId: doc.depotId,
        );
        _savedQty = {for (final l in doc.lines) l.produitId: l.quantite};
      }
      await _refreshAvailable();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: _docLabel(context), message: '$e');
      if (mounted) context.pop();
    }
  }

  Future<int?> _carLocationId(int userId) async {
    final cached = _carByUser[userId];
    if (cached != null) return cached;
    final user = await ref.read(userServiceProvider).getById(userId);
    if (user == null) return null;
    final car = await ref
        .read(stockLocationServiceProvider)
        .getOrCreateVirtualForUser(user);
    return _carByUser[userId] = car.id;
  }

  Future<int?> _sourceLocationId({int? userId, int? depotId}) async {
    if (_isCharge) return depotId;
    return userId == null ? null : _carLocationId(userId);
  }

  Future<void> _refreshAvailable() async {
    final sourceId = await _sourceLocationId(
      userId: _userId,
      depotId: _depotId,
    );
    if (sourceId == null) {
      _available = {};
      return;
    }
    final stock = await ref
        .read(stockBalanceServiceProvider)
        .getAllStocksAtLocation(sourceId);
    if (sourceId == _savedSourceId) {
      for (final e in _savedQty.entries) {
        stock[e.key] = (stock[e.key] ?? 0) + e.value;
      }
    }
    _available = stock;
  }

  Future<void> _onSourceChanged({int? userId, int? depotId}) async {
    setState(() {
      if (userId != null) _userId = userId;
      if (depotId != null) _depotId = depotId;
    });
    await _refreshAvailable();
    if (mounted) setState(() {});
  }

  DocumentTotals get _totals => DocumentTotals.fromLines(_lines);

  DocumentLine _lineFor(Produit p, double qty) => DocumentLine(
    produitId: p.id,
    reference: p.reference,
    designation: p.designation,
    quantite: qty,
    prixUnitaireHt: p.prixVenteHT,
    tauxTva: p.tauxTVA,
  );

  void _addProduct(Produit p) {
    setState(() {
      final i = _lines.indexWhere((l) => l.produitId == p.id);
      if (i >= 0) {
        _lines[i] = _lines[i].copyWith(quantite: _lines[i].quantite + 1);
      } else {
        _lines.add(_lineFor(p, 1));
      }
    });
  }

  Future<void> _unloadAll() async {
    final s = context.s;
    final full = [
      for (final p in _produits)
        if ((_available[p.id] ?? 0) > 0) _lineFor(p, _available[p.id]!),
    ];
    if (full.isEmpty) {
      await showErrorDialog(
        context,
        title: s.unloadAll,
        message: s.unloadAllEmpty,
      );
      return;
    }
    if (_lines.isNotEmpty) {
      final ok = await showConfirmDialog(
        context,
        title: s.unloadAll,
        message: s.unloadAllReplace,
      );
      if (!ok) return;
    }
    setState(() => _lines = full);
  }

  Future<void> _save() async {
    final s = context.s;
    final title = _docLabel(context);
    String? error;
    if (_userId == null) {
      error = s.errSelectVendeur;
    } else if (_depotId == null) {
      error = s.errSelectDepot;
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
      final sourceId = await _sourceLocationId(
        userId: _userId,
        depotId: _depotId,
      );
      final stockLines = _lines
          .where((l) => l.produitId > 0 && l.quantite > 0)
          .map((l) => (produitId: l.produitId, quantite: l.quantite));
      final shortages = await ref
          .read(stockMovementServiceProvider)
          .getOutboundShortages(
            fromLocationId: sourceId!,
            desiredOutboundLines: stockLines,
            origineType: _origineType,
            origineId: widget.bonId,
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

      final int id;
      if (_isCharge) {
        id = await ref
            .read(bonChargeServiceProvider)
            .save(
              id: widget.bonId,
              assignedToUserId: _userId!,
              depotLocationId: _depotId!,
              date: _date,
              note: _noteController.text,
              lines: _lines,
            );
      } else {
        id = await ref
            .read(bonDechargeServiceProvider)
            .save(
              id: widget.bonId,
              assignedToUserId: _userId!,
              depotLocationId: _depotId!,
              date: _date,
              note: _noteController.text,
              lines: _lines,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCharge ? s.bonChargeSaved : s.bonDechargeSaved),
        ),
      );
      context.pop(id);
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final title = _docLabel(context);
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(_numero),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      if (_isCharge) {
        await ref.read(bonChargeServiceProvider).delete(widget.bonId!);
      } else {
        await ref.read(bonDechargeServiceProvider).delete(widget.bonId!);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
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
        title: Text(_title(context)),
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
                if (_vendeurs.isEmpty)
                  Card(
                    color: AppColors.brandSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.noActiveVendeur),
                    ),
                  ),
                _buildHeader(context),
                const SizedBox(height: 16),
                ProductSearchCard(
                  produits: _produits,
                  onSelected: _addProduct,
                  available: _available,
                  headerActions: [
                    if (!_isCharge)
                      TextButton.icon(
                        onPressed: _userId == null ? null : _unloadAll,
                        icon: const Icon(Icons.move_down),
                        label: Text(s.unloadAll),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DocumentLinesTable(
                  lines: _lines,
                  available: _available,
                  images: productImagesById(_produits),
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
    final vendeurField = DropdownButtonFormField<int>(
      key: ValueKey('vendeur-$_userId-${_vendeurs.length}'),
      initialValue: _userId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: s.fieldVendeur,
        prefixIcon: const Icon(Icons.local_shipping_outlined),
      ),
      items: [
        for (final u in _vendeurs)
          DropdownMenuItem(
            value: u.id,
            child: Text(vendeurLabel(u), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) _onSourceChanged(userId: v);
      },
    );
    final depotField = DropdownButtonFormField<int>(
      key: ValueKey('depot-$_depotId-${_depots.length}'),
      initialValue: _depotId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: s.fieldDepot,
        prefixIcon: const Icon(Icons.warehouse_outlined),
      ),
      items: [
        for (final d in _depots)
          DropdownMenuItem(value: d.id, child: Text(d.nom)),
      ],
      onChanged: (v) {
        if (v != null) _onSourceChanged(depotId: v);
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isCharge ? Icons.upload_outlined : Icons.download_outlined,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 8),
                Text(
                  _isCharge ? s.bonChargeFlow : s.bonDechargeFlow,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isCharge) ...[
              depotField,
              const SizedBox(height: 12),
              vendeurField,
            ] else ...[
              vendeurField,
              const SizedBox(height: 12),
              depotField,
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('${s.fieldDate} : ${dateFormat.format(_date)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(BuildContext context) {
    final s = context.s;
    final totals = _totals;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
        ),
      ),
    );
  }
}
