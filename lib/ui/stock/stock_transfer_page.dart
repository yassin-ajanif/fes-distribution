import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class _TransferLine {
  _TransferLine(this.produit, this.quantite);

  final Produit produit;
  double quantite;
}

class StockTransferPage extends ConsumerStatefulWidget {
  const StockTransferPage({super.key});

  @override
  ConsumerState<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends ConsumerState<StockTransferPage> {
  final _noteController = TextEditingController();
  List<StockLocation> _depots = [];
  List<Produit> _produits = [];
  Map<int, double> _sourceStock = {};
  final List<_TransferLine> _lines = [];
  int? _fromId;
  int? _toId;
  bool _loading = true;
  bool _saving = false;

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

  Future<void> _load() async {
    try {
      final depots =
          await ref.read(stockLocationServiceProvider).getActivePhysicalLocations();
      final produits = await ref.read(produitServiceProvider).listActive();
      final fromId = depots.isNotEmpty ? depots.first.id : null;
      final toId = depots.length > 1 ? depots[1].id : null;
      final sourceStock = fromId == null
          ? <int, double>{}
          : await ref.read(stockBalanceServiceProvider).getAllStocksAtLocation(fromId);
      if (!mounted) return;
      setState(() {
        _depots = depots;
        _produits = produits;
        _fromId = fromId;
        _toId = toId;
        _sourceStock = sourceStock;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, title: context.s.transferTitle, message: '$e');
      if (mounted) context.pop();
    }
  }

  Future<void> _changeSource(int? id) async {
    if (id == null) return;
    final stock =
        await ref.read(stockBalanceServiceProvider).getAllStocksAtLocation(id);
    if (!mounted) return;
    setState(() {
      _fromId = id;
      if (_toId == id) _toId = null;
      _sourceStock = stock;
    });
  }

  void _addProduct(Produit p) {
    setState(() {
      final existing = _lines.where((l) => l.produit.id == p.id).firstOrNull;
      if (existing != null) {
        existing.quantite += 1;
      } else {
        _lines.add(_TransferLine(p, 1));
      }
    });
  }

  Future<void> _save() async {
    final s = context.s;
    if (_fromId == null || _toId == null || _fromId == _toId) {
      await showErrorDialog(context, title: s.transferTitle, message: s.needTwoDepots);
      return;
    }
    final valid = _lines.where((l) => l.quantite > 0).toList();
    if (valid.isEmpty) {
      await showErrorDialog(context, title: s.transferTitle, message: s.noLines);
      return;
    }

    final shortages = [
      for (final l in valid)
        if ((_sourceStock[l.produit.id] ?? 0) < l.quantite)
          s.shortageLine(
            l.produit.reference,
            formatQty(l.quantite),
            formatQty(_sourceStock[l.produit.id] ?? 0),
          ),
    ];
    if (shortages.isNotEmpty) {
      final ok = await showStockShortageDialog(context, lines: shortages);
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(stockMovementServiceProvider).transfer(
            fromLocationId: _fromId!,
            toLocationId: _toId!,
            lines: valid.map((l) => (produitId: l.produit.id, quantite: l.quantite)),
            note: _noteController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transferDone)),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: s.transferTitle, message: '$e');
      }
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
        title: Text(s.transferTitle),
        actions: [
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
                if (_depots.length < 2)
                  Card(
                    color: AppColors.brandSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.needTwoDepots),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _fromId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.fromDepot,
                            prefixIcon: const Icon(Icons.logout),
                          ),
                          items: [
                            for (final d in _depots)
                              DropdownMenuItem(value: d.id, child: Text(d.nom)),
                          ],
                          onChanged: _changeSource,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: ValueKey('to-$_fromId'),
                          initialValue: _toId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.toDepot,
                            prefixIcon: const Icon(Icons.login),
                          ),
                          items: [
                            for (final d in _depots.where((d) => d.id != _fromId))
                              DropdownMenuItem(value: d.id, child: Text(d.nom)),
                          ],
                          onChanged: (v) => setState(() => _toId = v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          decoration: InputDecoration(labelText: s.note),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
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
                              '${p.reference} — ${p.designation}',
                          onSelected: _addProduct,
                          fieldViewBuilder: (context, controller, focusNode, _) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: s.searchProduct,
                                prefixIcon: const Icon(Icons.search),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_lines.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          s.noLines,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _lines.length; i++)
                    _LineCard(
                      key: ValueKey(_lines[i].produit.id),
                      line: _lines[i],
                      available: _sourceStock[_lines[i].produit.id] ?? 0,
                      onChanged: (q) => setState(() => _lines[i].quantite = q),
                      onRemove: () => setState(() => _lines.removeAt(i)),
                    ),
              ],
            ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    super.key,
    required this.line,
    required this.available,
    required this.onChanged,
    required this.onRemove,
  });

  final _TransferLine line;
  final double available;
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final short = line.quantite > available;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.produit.designation,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${line.produit.reference} · ${s.available(formatQty(available))}',
                    style: TextStyle(
                      color: short ? AppColors.danger : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: formatQty(line.quantite),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                ],
                decoration: InputDecoration(labelText: s.quantity, isDense: true),
                onChanged: (v) => onChanged(
                  double.tryParse(
                        v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
                      ) ??
                      0,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
