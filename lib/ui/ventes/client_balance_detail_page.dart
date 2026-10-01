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

/// Breakdown of one client's debt: the figures on top, then every BL behind
/// them. Tapping a BL opens it.
class ClientBalanceDetailPage extends ConsumerStatefulWidget {
  const ClientBalanceDetailPage({super.key, required this.clientId});

  final int clientId;

  @override
  ConsumerState<ClientBalanceDetailPage> createState() =>
      _ClientBalanceDetailPageState();
}

class _ClientBalanceDetailPageState
    extends ConsumerState<ClientBalanceDetailPage> {
  ClientBalance? _balance;
  List<ClientBlLine> _bls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(clientBalanceServiceProvider);
      final balance = await service.get(widget.clientId);
      final bls = await service.blDetails(widget.clientId);
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _bls = bls;
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

  Future<void> _openBl(int blId) async {
    await context.push('/ventes/bons-livraison/$blId');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final b = _balance;

    return Scaffold(
      appBar: ShellAppBar(
        title: b?.clientNom ?? s.menuSoldeClients,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? LoadingView(message: s.loading)
          : b == null
              ? Center(
                  child: Text(
                    s.emptyClientsSolde,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _Summary(balance: b),
                    const SizedBox(height: 20),
                    Text(
                      s.balanceDetails,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_bls.isEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            s.emptyBl,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      for (final bl in _bls)
                        _BlRow(bl: bl, onTap: () => _openBl(bl.blId)),
                    // Avoirs point at a facture, so they are deducted here rather
                    // than being attributed to any single BL.
                    if (b.totalAvoir > 0)
                      _CreditNoteRow(amount: b.totalAvoir),
                  ],
                ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.balance});

  final ClientBalance balance;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final b = balance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.totalDu,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            b.doit ? formatMoney(b.solde) : s.balanceSettled,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: b.doit ? AppColors.danger : AppColors.brand,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryLine(
            label: '${s.balanceDelivered} (${s.balanceBlCount(b.nbBl)})',
            value: formatMoney(b.totalLivraison),
          ),
          _SummaryLine(
            label: s.balancePaid,
            value: formatMoney(b.totalPaye),
          ),
          if (b.totalAvoir > 0)
            _SummaryLine(
              label: s.balanceCreditNotes,
              value: '-${formatMoney(b.totalAvoir)}',
            ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BlRow extends StatelessWidget {
  const _BlRow({required this.bl, required this.onTap});

  final ClientBlLine bl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reste = bl.reste;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          title: Text(
            bl.numero,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            dateFormat.format(bl.date),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(bl.totalTtc),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                reste > 0.005 ? formatMoney(reste) : context.s.balanceSettled,
                style: TextStyle(
                  fontSize: 12,
                  color: reste > 0.005 ? AppColors.danger : AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditNoteRow extends StatelessWidget {
  const _CreditNoteRow({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      child: ListTile(
        leading: const Icon(Icons.undo_outlined, color: AppColors.muted),
        title: Text(
          context.s.balanceCreditNotes,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          '-${formatMoney(amount)}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }
}