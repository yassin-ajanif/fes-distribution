import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final _searchController = TextEditingController();
  List<StockLocation> _locations = [];
  int? _locationId;
  List<Produit> _produits = [];
  Map<int, double> _stock = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final locationService = ref.read(stockLocationServiceProvider);
      final locations = await locationService.getActiveLocations();
      var locationId = _locationId;
      if (locationId == null || !locations.any((l) => l.id == locationId)) {
        locationId = (await locationService.getOrCreateDefaultDepot()).id;
      }
      final produits = await ref
          .read(produitServiceProvider)
          .listActive(search: _searchController.text);
      final stock = await ref
          .read(stockBalanceServiceProvider)
          .getAllStocksAtLocation(locationId);
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _locationId = locationId;
        _produits = produits;
        _stock = stock;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: context.s.menuStock, message: '$e');
      }
    }
  }

  String _locationLabel(StockLocation l) {
    final s = context.s;
    return '${l.nom} (${l.isVirtual ? s.locationVirtual : s.locationPhysical})';
  }

  Future<String?> _askText({
    required String title,
    required String label,
  }) async {
    final s = context.s;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(s.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createDepot() async {
    final s = context.s;
    final nom = await _askText(title: s.newDepot, label: s.fieldName);
    if (nom == null || nom.trim().isEmpty) return;
    try {
      final depot =
          await ref.read(stockLocationServiceProvider).createPhysicalLocation(nom);
      _locationId = depot.id;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.depotCreated)),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: s.newDepot, message: '$e');
      }
    }
  }

  Future<void> _adjust(Produit p) async {
    final s = context.s;
    final result = await showDialog<({double delta, String motif})>(
      context: context,
      builder: (ctx) => _AdjustDialog(
        produit: p,
        current: _stock[p.id] ?? 0,
      ),
    );
    if (result == null) return;

    if (result.delta < 0) {
      final available = _stock[p.id] ?? 0;
      if (available < -result.delta) {
        if (!mounted) return;
        final ok = await showStockShortageDialog(
          context,
          lines: [
            s.shortageLine(
              p.reference,
              formatQty(-result.delta),
              formatQty(available),
            ),
          ],
        );
        if (!ok) return;
      }
    }

    try {
      await ref.read(stockMovementServiceProvider).applyAdjustment(
            produitId: p.id,
            locationId: _locationId!,
            delta: result.delta,
            note: result.motif,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.adjustDone)),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: s.adjustStock, message: '$e');
      }
    }
  }

  Future<void> _openTransfer() async {
    await context.push('/stock/transfert');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuStock,
        actions: [
          IconButton(
            tooltip: s.newDepot,
            icon: const Icon(Icons.add_business_outlined),
            onPressed: _loading ? null : _createDepot,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTransfer,
        icon: const Icon(Icons.swap_horiz),
        label: Text(s.transfer),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<int>(
              key: ValueKey('loc-$_locationId-${_locations.length}'),
              initialValue: _locationId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.stockLocation,
                prefixIcon: const Icon(Icons.warehouse_outlined),
              ),
              items: [
                for (final l in _locations)
                  DropdownMenuItem(value: l.id, child: Text(_locationLabel(l))),
              ],
              onChanged: (v) {
                if (v == null) return;
                _locationId = v;
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.searchStock,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? LoadingView(message: s.loading)
                : _produits.isEmpty
                    ? Center(
                        child: Text(
                          s.emptyStock,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: _produits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = _produits[index];
                          final qty = _stock[p.id] ?? 0;
                          final low = qty <= 0 ||
                              (p.stockMinimum > 0 && qty < p.stockMinimum);
                          return Card(
                            child: ListTile(
                              onTap: () => _adjust(p),
                              title: Text(
                                p.designation,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(p.reference),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatQty(qty)} ${p.unite}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: low ? AppColors.danger : AppColors.brand,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.tune, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.produit, required this.current});

  final Produit produit;
  final double current;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _delta = TextEditingController();
  final _motif = TextEditingController();

  @override
  void dispose() {
    _delta.dispose();
    _motif.dispose();
    super.dispose();
  }

  double? get _parsed => double.tryParse(_delta.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final delta = _parsed;
    final after = widget.current + (delta ?? 0);

    return AlertDialog(
      title: Text(s.adjustStock),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.produit.reference} — ${widget.produit.designation}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('${s.currentStock} : ${formatQty(widget.current)} ${widget.produit.unite}'),
          const SizedBox(height: 16),
          TextField(
            controller: _delta,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
            decoration: InputDecoration(labelText: s.adjustDelta),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motif,
            decoration: InputDecoration(labelText: s.adjustMotif),
          ),
          const SizedBox(height: 12),
          Text(
            '→ ${formatQty(after)} ${widget.produit.unite}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: after < 0 ? AppColors.danger : AppColors.brand,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.actionCancel),
        ),
        FilledButton(
          onPressed: delta == null || delta == 0
              ? null
              : () => Navigator.of(context).pop(
                    (delta: delta, motif: _motif.text),
                  ),
          child: Text(s.actionConfirm),
        ),
      ],
    );
  }
}
