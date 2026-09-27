import 'package:flutter/material.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

/// HT / TVA / TTC summary. [leading] (e.g. the remise field) sits on the
/// left, [extra] lines go under the TTC (e.g. paid / remaining).
class DocumentTotalsCard extends StatelessWidget {
  const DocumentTotalsCard({
    super.key,
    required this.totals,
    this.leading,
    this.extra = const [],
  });

  final DocumentTotals totals;
  final Widget? leading;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment:
              leading == null ? WrapAlignment.end : WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            ?leading,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(s.totalHt(formatMoney(totals.totalHt))),
                Text(s.totalTva(formatMoney(totals.totalTva))),
                Text(
                  s.totalTtc(formatMoney(totals.totalTtc)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...extra,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
