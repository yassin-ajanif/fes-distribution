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

/// Breakdown of one supplier's debt: the figures on top, then the factures
/// (which carry the payments) and the BRs no facture covers yet.
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

  Future<void> _openDocument(SupplierBalanceLine line) async {
    final path = line.kind == SupplierDocumentKind.facture
        ? '/achats/factures-fournisseur/${line.documentId}'
        : '/achats/bons-reception/${line.documentId}';
    await context.push(path);
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
                  '${s.balanceReceived} (${s.supplierDocumentCount(b.nbFacture)})',
                  formatMoney(b.totalFacture),
                ),
                (s.balancePendingBr, formatMoney(b.totalBrNonFacture)),
                (s.balancePaid, formatMoney(b.totalPaye)),
              ],
        detailLabel: s.supplierDocumentsLabel,
        documents: [
          for (final d in _documents)
            TiersBalanceDocument(
              id: d.documentId,
              title: d.numero,
              subtitle:
                  '${d.kind == SupplierDocumentKind.facture ? s.menuFactures : s.menuBr} • '
                  '${dateFormat.format(d.date)}',
              total: d.totalTtc,
              reste: d.reste,
              tag: d,
            ),
        ],
        // A supplier avoir carries no link to a facture, so it is only ever
        // deducted at the supplier level.
        creditNoteLabel: s.balanceCreditNotes,
        creditNoteAmount: b?.totalAvoir ?? 0,
        emptyText: s.emptyBr,
        onTapDocument: (doc) =>
            _openDocument(doc.tag! as SupplierBalanceLine),
      ),
    );
  }
}