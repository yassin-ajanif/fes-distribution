import 'package:flutter/material.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class DocumentLinesTable extends StatelessWidget {
  const DocumentLinesTable({
    super.key,
    required this.lines,
    required this.selectedIndex,
    required this.onSelect,
    required this.onChanged,
    required this.onRemoveAt,
  });

  final List<PersonnelDocumentLine> lines;
  final int? selectedIndex;
  final ValueChanged<int?> onSelect;
  final void Function(int index) onRemoveAt;
  final void Function(int index, PersonnelDocumentLine line) onChanged;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Aucune ligne — ajoutez un produit ci-dessus.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    if (isMobile(context)) {
      return Column(
        children: [
          for (var i = 0; i < lines.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: selectedIndex == i ? AppColors.brandSoft : null,
              child: InkWell(
                onTap: () => onSelect(selectedIndex == i ? null : i),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lines[i].reference,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => onRemoveAt(i),
                          ),
                        ],
                      ),
                      TextFormField(
                        key: ValueKey('des-${lines[i].produitId}-${lines[i].designation}'),
                        initialValue: lines[i].designation,
                        decoration: const InputDecoration(
                          labelText: 'Désignation',
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            onChanged(i, lines[i].copyWith(designation: v)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: ValueKey('qty-${lines[i].produitId}-${lines[i].quantite}'),
                        initialValue: formatQty(lines[i].quantite),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final q = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          onChanged(i, lines[i].copyWith(quantite: q));
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('PU HT: ${formatMoney(lines[i].prixUnitaireHt)}'),
                          Text(
                            'TTC: ${formatMoney(lines[i].montantTtc)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(AppColors.brandSoft),
          columns: const [
            DataColumn(label: Text('Réf.')),
            DataColumn(label: Text('Désignation')),
            DataColumn(label: Text('Qté'), numeric: true),
            DataColumn(label: Text('PU HT'), numeric: true),
            DataColumn(label: Text('Rem.%'), numeric: true),
            DataColumn(label: Text('TVA%'), numeric: true),
            DataColumn(label: Text('Montant HT'), numeric: true),
            DataColumn(label: Text('Montant TTC'), numeric: true),
          ],
          rows: [
            for (var i = 0; i < lines.length; i++)
              DataRow(
                selected: selectedIndex == i,
                onSelectChanged: (_) => onSelect(i),
                cells: [
                  DataCell(Text(lines[i].reference)),
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        initialValue: lines[i].designation,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (v) =>
                            onChanged(i, lines[i].copyWith(designation: v)),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: formatQty(lines[i].quantite),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) {
                          final q = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          onChanged(i, lines[i].copyWith(quantite: q));
                        },
                      ),
                    ),
                  ),
                  DataCell(Text(formatMoney(lines[i].prixUnitaireHt))),
                  DataCell(Text(formatQty(lines[i].remise))),
                  DataCell(Text(formatQty(lines[i].tauxTva))),
                  DataCell(Text(formatMoney(lines[i].montantHt))),
                  DataCell(Text(formatMoney(lines[i].montantTtc))),
                ],
              ),
          ],
        ),
      ),
    );
  }

}
