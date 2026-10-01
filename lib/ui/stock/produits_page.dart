import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class ProduitsPage extends ConsumerStatefulWidget {
  const ProduitsPage({super.key});

  @override
  ConsumerState<ProduitsPage> createState() => _ProduitsPageState();
}

class _ProduitsPageState extends ConsumerState<ProduitsPage> {
  /// How many products are fetched per page.
  static const _pageSize = 50;

  final _searchController = TextEditingController();
  List<Produit> _produits = [];
  List<StockLocation> _locations = [];
  int? _locationId;
  Map<int, double> _stock = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

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

  Future<void> _load({int? limit, bool silent = false}) async {
    final requested = limit ?? _pageSize;
    setState(() {
      // A silent refresh keeps the current grid (and its scroll position) on
      // screen while the data is re-read.
      if (!silent) _loading = true;
      _loadingMore = false;
    });
    try {
      final (locations, locationId) = await _resolveLocations();
      final produits = await ref
          .read(produitServiceProvider)
          .listCatalog(search: _searchController.text, limit: requested);
      final stock = await ref
          .read(stockBalanceServiceProvider)
          .getAllStocksAtLocation(locationId);
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _locationId = locationId;
        _produits = produits;
        _stock = stock;
        _offset = produits.length;
        _hasMore = produits.length == requested;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(
          context,
          title: context.s.menuProduits,
          message: '$e',
        );
      }
    }
  }

  /// Fetches the next page and appends it; called as the grid nears its end.
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(produitServiceProvider)
          .listCatalog(
            search: _searchController.text,
            limit: _pageSize,
            offset: _offset,
          );
      if (!mounted) return;
      setState(() {
        _produits = [..._produits, ...next];
        _offset += next.length;
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        await showErrorDialog(
          context,
          title: context.s.menuProduits,
          message: '$e',
        );
      }
    }
  }

  /// Returns the active locations and the one currently selected, falling back
  /// to the default depot ("stock principal") when nothing valid is set.
  Future<(List<StockLocation>, int)> _resolveLocations() async {
    final service = ref.read(stockLocationServiceProvider);
    var locations = await service.getActiveLocations();
    var locationId = _locationId;
    if (locationId == null || !locations.any((l) => l.id == locationId)) {
      final depot = await service.getOrCreateDefaultDepot();
      locationId = depot.id;
      // The default depot can be inactive, in which case it is absent from the
      // active list; adding it back keeps the dropdown's value present exactly
      // once (DropdownButtonFormField asserts on that).
      if (!locations.any((l) => l.id == depot.id)) {
        locations = [...locations, depot];
      }
    }
    return (locations, locationId);
  }

  /// Switches the stock column without re-reading the product list, so the
  /// loaded pages and scroll position are kept.
  Future<void> _switchLocation(int locationId) async {
    setState(() => _locationId = locationId);
    try {
      final stock = await ref
          .read(stockBalanceServiceProvider)
          .getAllStocksAtLocation(locationId);
      if (!mounted) return;
      setState(() => _stock = stock);
    } catch (e) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: context.s.menuProduits,
          message: '$e',
        );
      }
    }
  }

  String _locationLabel(StockLocation l) {
    final s = context.s;
    return '${l.nom} (${l.isVirtual ? s.locationVirtual : s.locationPhysical})';
  }

  /// Re-reads the range already loaded so that returning from an edit keeps
  /// the user where they were instead of jumping back to the first page.
  Future<void> _refreshLoaded() => _load(
    limit: _produits.isEmpty ? null : _produits.length,
    silent: true,
  );

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _refreshLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuProduits,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshLoaded,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('/stock/produits/new'),
        icon: const Icon(Icons.add),
        label: Text(s.actionNew),
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
                  DropdownMenuItem(
                    value: l.id,
                    child: Text(_locationLabel(l)),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                _switchLocation(v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.searchProduits,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  },
                ),
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
                      s.emptyProduits,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : _ProduitGrid(
                    produits: _produits,
                    stock: _stock,
                    hasMore: _hasMore,
                    loadingMore: _loadingMore,
                    onLoadMore: _loadMore,
                    onTap: (p) => _open('/stock/produits/${p.id}'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProduitGrid extends StatelessWidget {
  const _ProduitGrid({
    required this.produits,
    required this.stock,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onTap,
  });

  final List<Produit> produits;
  final Map<int, double> stock;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final ValueChanged<Produit> onTap;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // Fetch the next page before the user actually reaches the bottom so the
      // grid keeps filling without a visible pause.
      onNotification: (notification) {
        if (hasMore &&
            !loadingMore &&
            notification.metrics.extentAfter < 400) {
          onLoadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: produitGridColumns(context),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.76,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final p = produits[index];
                return _ProduitCard(
                  produit: p,
                  qty: stock[p.id] ?? 0,
                  onTap: () => onTap(p),
                );
              }, childCount: produits.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: hasMore
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProduitCard extends StatelessWidget {
  const _ProduitCard({
    required this.produit,
    required this.qty,
    required this.onTap,
  });

  final Produit produit;
  final double qty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = produit;
    final low = p.stockMinimum > 0 && qty < p.stockMinimum;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CardImage(produit: p),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _StockBadge(
                      label: '${formatQty(qty)} ${p.unite}',
                      low: low,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.designation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: p.actif ? null : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatMoney(p.prixVenteHT),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      if (!p.actif)
                        Text(
                          s.inactive,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fills the top of a card with the product photo, falling back to an icon.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.produit});

  final Produit produit;

  @override
  Widget build(BuildContext context) {
    final bytes = produit.imageData;
    if (bytes == null || bytes.isEmpty) {
      return _placeholder();
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.brandSoft,
      child: Icon(
        produit.actif ? Icons.inventory_2 : Icons.block,
        size: 40,
        color: produit.actif ? AppColors.brand : AppColors.muted,
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.label, required this.low});

  final String label;
  final bool low;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (low ? AppColors.danger : AppColors.brand).withValues(
          alpha: 0.92,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
