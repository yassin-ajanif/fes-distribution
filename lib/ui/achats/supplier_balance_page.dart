import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/supplier_balance.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/common/tiers_balance_view.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

/// "Solde fournisseurs": what we still owe each supplier, biggest first.
///
/// A supplier owes nothing to us, so the figure is what *we* have to pay:
/// factures + BRs not yet invoiced − payments − credit notes.
class SupplierBalancePage extends ConsumerStatefulWidget {
  const SupplierBalancePage({super.key});

  @override
  ConsumerState<SupplierBalancePage> createState() => _SupplierBalancePageState();
}

class _SupplierBalancePageState extends ConsumerState<SupplierBalancePage> {
  final _searchController = TextEditingController();
  List<SupplierBalance> _balances = [];
  bool _loading = true;
  bool _tousLesFournisseurs = false;

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
      final balances = await ref.read(supplierBalanceServiceProvider).list(
            search: _searchController.text,
            uniquementAvecSolde: !_tousLesFournisseurs,
          );
      if (!mounted) return;
      setState(() {
        _balances = balances;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(
          context,
          title: context.s.menuSoldeFournisseurs,
          message: '$e',
        );
      }
    }
  }

  Future<void> _open(int fournisseurId) async {
    await context.push('/achats/solde-fournisseurs/$fournisseurId');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuSoldeFournisseurs,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: TiersBalanceListView(
        rows: [
          for (final b in _balances)
            TiersBalanceRow(
              id: b.fournisseurId,
              name: b.fournisseurNom,
              subtitle: '${s.supplierDocumentCount(b.nbFacture + b.nbBrNonFacture)} • '
                  '${s.balanceReceived} ${formatMoney(b.totalRecu)} • '
                  '${s.balancePaid} ${formatMoney(b.totalPaye)}',
              amount: b.solde,
              owes: b.doit,
            ),
        ],
        loading: _loading,
        searchController: _searchController,
        searchHint: s.searchFournisseurs,
        filterLabel: s.filterAllFournisseurs,
        showAll: _tousLesFournisseurs,
        totalLabel: s.totalAPayer,
        settledLabel: s.balanceSettled,
        emptyText: s.emptyFournisseursSolde,
        onSearch: _load,
        onClearSearch: () {
          _searchController.clear();
          _load();
        },
        onToggleShowAll: (v) {
          setState(() => _tousLesFournisseurs = v);
          _load();
        },
        onRefresh: _load,
        onTap: _open,
      ),
    );
  }
}