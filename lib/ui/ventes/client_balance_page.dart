import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/client_balance.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// "Solde clients": what every client still owes, biggest debt first.
///
/// The figure per client is BL totals − payments − credit notes (avoirs).
class ClientBalancePage extends ConsumerStatefulWidget {
  const ClientBalancePage({super.key});

  @override
  ConsumerState<ClientBalancePage> createState() => _ClientBalancePageState();
}

class _ClientBalancePageState extends ConsumerState<ClientBalancePage> {
  final _searchController = TextEditingController();
  List<ClientBalance> _balances = [];
  bool _loading = true;
  bool _tousLesClients = false;

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
      final balances = await ref.read(clientBalanceServiceProvider).list(
            search: _searchController.text,
            uniquementAvecSolde: !_tousLesClients,
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
          title: context.s.menuSoldeClients,
          message: '$e',
        );
      }
    }
  }

  Future<void> _open(int clientId) async {
    await context.push('/ventes/solde-clients/$clientId');
    if (mounted) _load();
  }

  /// Sum of the debts actually listed, so the header never counts a client the
  /// list is hiding.
  double get _totalDu => _balances.fold(
        0.0,
        (sum, b) => sum + (b.doit ? b.solde : 0),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuSoldeClients,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.searchClients,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                selected: _tousLesClients,
                label: Text(s.filterAllClients),
                avatar: Icon(
                  Icons.people_outline,
                  size: 18,
                  color: _tousLesClients ? AppColors.brand : AppColors.muted,
                ),
                onSelected: (v) {
                  setState(() => _tousLesClients = v);
                  _load();
                },
              ),
            ),
          ),
          if (!_loading && _balances.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _TotalCard(total: _totalDu, label: s.totalDu),
            ),
          Expanded(
            child: _loading
                ? LoadingView(message: s.loading)
                : _balances.isEmpty
                    ? Center(
                        child: Text(
                          s.emptyClientsSolde,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _balances.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final b = _balances[index];
                          return _BalanceCard(
                            balance: b,
                            onTap: () => _open(b.clientId),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.label});

  final double total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(total),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onTap});

  final ClientBalance balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final b = balance;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.clientNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.balanceBlCount(b.nbBl)} • '
                      '${s.balanceDelivered} ${formatMoney(b.totalLivraison)} • '
                      '${s.balancePaid} ${formatMoney(b.totalPaye)}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                b.doit ? formatMoney(b.solde) : s.balanceSettled,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: b.doit ? AppColors.danger : AppColors.brand,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}