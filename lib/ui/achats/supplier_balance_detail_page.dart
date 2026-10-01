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

/// Breakdown of one supplier's debt: the figures on top, then every BR behind
/// them, each with what was paid on it. Tapping a BR opens it.
class SupplierBalanceDetailPage extends ConsumerStatefulWidget {
  const SupplierBalanceDetailPage({super.key, required this.fournisseurId});

  final int fournisseurId;

  @override
  ConsumerState<SupplierBalanceDetailPage> createState() =>
      _SupplierBalanceDetailPageState();
}

class _SupplierBalanceDetailPageState
    extends ConsumerState<SupplierBalanceDetailPage> {
  SupplierBalance? _balance;
  List<SupplierBalanceLine> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(supplierBalanceServiceProvider);
      final balance = await service.get(widget.fournisseurId);
      final documents = await service.documentDetails(widget.fournisseurId);
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _documents = documents;
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

  Future<void> _openBr(int brId) async {
    await context.push('/achats/bons-reception/$brId');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final b = _balance;

    return Scaffold(
      appBar: ShellAppBar(
        title: b?.fournisseurNom ?? s.menuSoldeFournisseurs,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: TiersBalanceDetailView(
        loading: _loading,
        totalLabel: s.totalAPayer,
        total: b?.solde ?? 0,
        owes: b?.doit ?? false,
        summaryLines: b == null
            ? const []
            : [
                (
                  '${s.balanceReceived} (${s.balanceBrCount(b.nbBr)})',
                  formatMoney(b.totalLivraison),
                ),
                (s.balancePaid, formatMoney(b.totalPaye)),
              ],
        detailLabel: s.balanceBrDetails,
        documents: [
          for (final d in _documents)
            TiersBalanceDocument(
              id: d.brId,
              title: d.numero,
              subtitle: d.factureNumero == null
                  ? dateFormat.format(d.date)
                  : '${s.menuFacturesFournisseur} ${d.factureNumero} • '
                      '${dateFormat.format(d.date)}',
              total: d.totalTtc,
              reste: d.reste,
            ),
        ],
        // A supplier avoir carries no link to a BR, so it is only ever deducted
        // at the supplier level.
        creditNoteLabel: s.balanceCreditNotes,
        creditNoteAmount: b?.totalAvoir ?? 0,
        emptyText: s.emptyBr,
        onTapDocument: (doc) => _openBr(doc.id),
      ),
    );
  }
}