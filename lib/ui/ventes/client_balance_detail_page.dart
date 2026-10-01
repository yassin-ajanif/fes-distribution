import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/client_balance.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/common/tiers_balance_view.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

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
      body: TiersBalanceDetailView(
        loading: _loading,
        totalLabel: s.totalDu,
        total: b?.solde ?? 0,
        owes: b?.doit ?? false,
        summaryLines: b == null
            ? const []
            : [
                (
                  '${s.balanceDelivered} (${s.balanceBlCount(b.nbBl)})',
                  formatMoney(b.totalLivraison),
                ),
                (s.balancePaid, formatMoney(b.totalPaye)),
              ],
        detailLabel: s.balanceDetails,
        documents: [
          for (final bl in _bls)
            TiersBalanceDocument(
              id: bl.blId,
              title: bl.numero,
              subtitle: dateFormat.format(bl.date),
              total: bl.totalTtc,
              reste: bl.reste,
            ),
        ],
        // Avoirs point at a facture, so they are deducted here rather than
        // being attributed to any single BL.
        creditNoteLabel: s.balanceCreditNotes,
        creditNoteAmount: b?.totalAvoir ?? 0,
        emptyText: s.emptyBl,
        onTapDocument: (doc) => _openBl(doc.id),
      ),
    );
  }
}