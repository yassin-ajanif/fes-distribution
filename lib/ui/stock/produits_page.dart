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
  final _searchController = TextEditingController();
  List<Produit> _produits = [];
  Map<int, double> _stockDepots = {};
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
      final produits = await ref
          .read(produitServiceProvider)
          .listCatalog(search: _searchController.text);
      final depots =
          await ref.read(stockLocationServiceProvider).getActivePhysicalLocations();
      final balance = ref.read(stockBalanceServiceProvider);
      final totals = <int, double>{};
      for (final depot in depots) {
        final stocks = await balance.getAllStocksAtLocation(depot.id);
        stocks.forEach((id, qty) => totals[id] = (totals[id] ?? 0) + qty);
      }
      if (!mounted) return;
      setState(() {
        _produits = produits;
        _stockDepots = totals;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: context.s.menuProduits, message: '$e');
      }
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _load();
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
            onPressed: _loading ? null : _load,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    : isMobile(context)
                        ? _MobileList(
                            produits: _produits,
                            stock: _stockDepots,
                            onTap: (p) => _open('/stock/produits/${p.id}'),
                          )
                        : _DesktopTable(
                            produits: _produits,
                            stock: _stockDepots,
                            onTap: (p) => _open('/stock/produits/${p.id}'),
                          ),
          ),
        ],
      ),
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.produits,
    required this.stock,
    required this.onTap,
  });

  final List<Produit> produits;
  final Map<int, double> stock;
  final ValueChanged<Produit> onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: produits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = produits[index];
        final qty = stock[p.id] ?? 0;
        final low = p.stockMinimum > 0 && qty < p.stockMinimum;
        return Card(
          child: ListTile(
            onTap: () => onTap(p),
            leading: CircleAvatar(
              backgroundColor: AppColors.brandSoft,
              child: Icon(
                p.actif ? Icons.inventory_2 : Icons.block,
                color: p.actif ? AppColors.brand : AppColors.muted,
              ),
            ),
            title: Text(
              p.designation,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: p.actif ? null : AppColors.muted,
              ),
            ),
            subtitle: Text(
              '${p.reference} · ${formatMoney(p.prixVenteHT)}'
              '${p.actif ? '' : ' · ${s.inactive}'}',
            ),
            trailing: Text(
              '${formatQty(qty)} ${p.unite}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: low ? AppColors.danger : AppColors.brand,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.produits,
    required this.stock,
    required this.onTap,
  });

  final List<Produit> produits;
  final Map<int, double> stock;
  final ValueChanged<Produit> onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(AppColors.brandSoft),
            columns: [
              DataColumn(label: Text(s.fieldReference)),
              DataColumn(label: Text(s.fieldDesignation)),
              DataColumn(label: Text(s.fieldUnite)),
              DataColumn(label: Text(s.fieldPrixAchat), numeric: true),
              DataColumn(label: Text(s.fieldPrixVente), numeric: true),
              DataColumn(label: Text(s.stockDepots), numeric: true),
              DataColumn(label: Text(s.fieldActif)),
            ],
            rows: [
              for (final p in produits)
                DataRow(
                  onSelectChanged: (_) => onTap(p),
                  cells: [
                    DataCell(Text(p.reference)),
                    DataCell(Text(p.designation)),
                    DataCell(Text(p.unite)),
                    DataCell(Text(formatMoney(p.prixAchatHT))),
                    DataCell(Text(formatMoney(p.prixVenteHT))),
                    DataCell(
                      Text(
                        formatQty(stock[p.id] ?? 0),
                        style: TextStyle(
                          color: p.stockMinimum > 0 &&
                                  (stock[p.id] ?? 0) < p.stockMinimum
                              ? AppColors.danger
                              : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Icon(
                        p.actif ? Icons.check_circle : Icons.block,
                        size: 18,
                        color: p.actif ? AppColors.brand : AppColors.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
