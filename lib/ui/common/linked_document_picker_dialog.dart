import 'package:flutter/material.dart';
import 'package:fes_distribution/business/models/linked_document.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

/// Multi-select of source documents to invoice (BLs on a facture, BRs on a
/// facture fournisseur). Pops the selected documents.
Future<List<LinkedDocument>?> showLinkedDocumentPicker(
  BuildContext context, {
  required String title,
  required List<LinkedDocument> documents,
}) =>
    showDialog<List<LinkedDocument>>(
      context: context,
      builder: (_) => _PickerDialog(title: title, documents: documents),
    );

class _PickerDialog extends StatefulWidget {
  const _PickerDialog({required this.title, required this.documents});

  final String title;
  final List<LinkedDocument> documents;

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final doc in widget.documents)
              CheckboxListTile(
                value: _selected.contains(doc.id),
                title: Text(doc.numero),
                subtitle: Text(
                  '${dateFormat.format(doc.date)} · ${formatMoney(doc.totalTtc)}',
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(doc.id);
                  } else {
                    _selected.remove(doc.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.actionCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    widget.documents
                        .where((d) => _selected.contains(d.id))
                        .toList(),
                  ),
          child: Text(s.actionConfirm),
        ),
      ],
    );
  }
}
