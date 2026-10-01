import 'package:flutter/material.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Shared presentation for the "solde clients" / "solde fournisseurs" pages.
///
/// The two balances are shaped differently (a client owes on their BLs, a
/// supplier on their factures), so the pages build their own figures and hand
/// ready-to-render rows over to these widgets. That keeps the layout, the
/// colours and the wording consistent without duplicating the whole screen.

/// One row of a balance list.
class TiersBalanceRow {
  const TiersBalanceRow({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.owes,
  });

  final int id;
  final String name;

  /// Secondary line, already phrased by the caller.
  final String subtitle;

  /// Outstanding amount.
  final double amount;

  /// False for a settled tier, which is shown in green with a "Soldé" tag.
  final bool owes;
}

/// One document behind a balance (a BL, a facture fournisseur, a BR…).
class TiersBalanceDocument {
  const TiersBalanceDocument({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.reste,
    this.tag,
  });

  final int id;
  final String title;
  final String subtitle;
  final double total;

  /// Left to pay on this document alone.
  final double reste;

  /// Anything the page needs to identify the document once tapped. Documents
  /// of different kinds can share the same numeric id, so callers that need
  /// more than the id should carry it here.
  final Object? tag;
}

class TiersBalanceListView extends StatelessWidget {
  const TiersBalanceListView({
    super.key,
    required this.rows,
    required this.loading,
    required this.searchController,
    required this.searchHint,
    required this.filterLabel,
    required this.showAll,
    required this.totalLabel,
    required this.settledLabel,
    required this.emptyText,
    required this.onSearch,
    required this.onClearSearch,
    required this.onToggleShowAll,
    required this.onRefresh,
    required this.onTap,
  });

  final List<TiersBalanceRow> rows;
  final bool loading;
  final TextEditingController searchController;
  final String searchHint;
  final String filterLabel;
  final bool showAll;
  final String totalLabel;
  final String settledLabel;
  final String emptyText;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<bool> onToggleShowAll;
  final VoidCallback onRefresh;
  final ValueChanged<int> onTap;

  /// Sums only the debts actually listed, so the header never counts a tier
  /// the list is hiding.
  double get _total => rows.fold(
        0.0,
        (sum, r) => sum + (r.owes ? r.amount : 0),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClearSearch,
              ),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              selected: showAll,
              label: Text(filterLabel),
              avatar: Icon(
                Icons.people_outline,
                size: 18,
                color: showAll ? AppColors.brand : AppColors.muted,
              ),
              onSelected: onToggleShowAll,
            ),
          ),
        ),
        if (!loading && rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _TotalCard(total: _total, label: totalLabel),
          ),
        Expanded(
          child: loading
              ? LoadingView(message: s.loading)
              : rows.isEmpty
                  ? Center(
                      child: Text(
                        emptyText,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => onRefresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _BalanceRow(
                          row: rows[index],
                          settledLabel: settledLabel,
                          onTap: () => onTap(rows[index].id),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class TiersBalanceDetailView extends StatelessWidget {
  const TiersBalanceDetailView({
    super.key,
    required this.loading,
    required this.totalLabel,
    required this.total,
    required this.owes,
    required this.summaryLines,
    required this.detailLabel,
    required this.documents,
    required this.creditNoteLabel,
    required this.creditNoteAmount,
    required this.emptyText,
    required this.onTapDocument,
  });

  final bool loading;

  /// Headline figure, e.g. "Total dû".
  final String totalLabel;
  final double total;
  final bool owes;

  /// Label/value pairs listed under the headline.
  final List<(String, String)> summaryLines;

  /// Heading above the document list.
  final String detailLabel;
  final List<TiersBalanceDocument> documents;

  /// Null when there is no credit note to deduct.
  final String? creditNoteLabel;
  final double creditNoteAmount;

  final String emptyText;
  final ValueChanged<TiersBalanceDocument> onTapDocument;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    if (loading) return LoadingView(message: s.loading);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
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
                totalLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                owes ? formatMoney(total) : s.balanceSettled,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: owes ? AppColors.danger : AppColors.brand,
                ),
              ),
              const SizedBox(height: 12),
              for (final (label, value) in summaryLines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          detailLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
        ),
        const SizedBox(height: 8),
        if (documents.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(emptyText, style: TextStyle(color: AppColors.muted)),
            ),
          )
        else
          for (final doc in documents)
            _DocumentRow(
              document: doc,
              settledLabel: s.balanceSettled,
              onTap: () => onTapDocument(doc),
            ),
        if (creditNoteLabel != null && creditNoteAmount > 0)
          Card(
            margin: const EdgeInsets.only(top: 8),
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.undo_outlined, color: AppColors.muted),
              title: Text(
                creditNoteLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                '-${formatMoney(creditNoteAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
      ],
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
            style: const TextStyle(
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

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.row,
    required this.settledLabel,
    required this.onTap,
  });

  final TiersBalanceRow row;
  final String settledLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                row.owes ? formatMoney(row.amount) : settledLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: row.owes ? AppColors.danger : AppColors.brand,
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

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.settledLabel,
    required this.onTap,
  });

  final TiersBalanceDocument document;
  final String settledLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reste = document.reste;
    final owes = !DocumentTotals.isEffectivelyZero(reste);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          title: Text(
            document.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            document.subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(document.total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                owes ? formatMoney(reste) : settledLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: owes ? AppColors.danger : AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}