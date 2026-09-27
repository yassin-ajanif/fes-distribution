import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fes_distribution/business/enums/mode_paiement.dart';
import 'package:fes_distribution/business/models/document_paiement.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/l10n/app_strings.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

extension ModePaiementLabel on ModePaiement {
  String label(AppStrings s) => switch (this) {
        ModePaiement.credit => s.modeCredit,
        ModePaiement.cheque => s.modeCheque,
        ModePaiement.especes => s.modeEspeces,
        ModePaiement.tpe => s.modeTpe,
        ModePaiement.virement => s.modeVirement,
        ModePaiement.effet => s.modeEffet,
      };
}

/// Asks for one payment; [suggested] pre-fills the amount (remaining to pay).
Future<DocumentPaiement?> showPaiementDialog(
  BuildContext context, {
  required double suggested,
}) =>
    showDialog<DocumentPaiement>(
      context: context,
      builder: (_) => _PaiementDialog(suggested: suggested),
    );

class _PaiementDialog extends StatefulWidget {
  const _PaiementDialog({required this.suggested});

  final double suggested;

  @override
  State<_PaiementDialog> createState() => _PaiementDialogState();
}

class _PaiementDialogState extends State<_PaiementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _montant = TextEditingController(
    text: widget.suggested > 0 ? widget.suggested.toStringAsFixed(2) : '',
  );
  final _reference = TextEditingController();
  DateTime _date = DateTime.now();
  ModePaiement _mode = ModePaiement.especes;

  @override
  void dispose() {
    _montant.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.addPaiement),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _montant,
              autofocus: true,
              decoration: InputDecoration(labelText: s.fieldMontant),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (v) => parseQty(v ?? '') <= 0 ? s.errAmount : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ModePaiement>(
              initialValue: _mode,
              decoration: InputDecoration(labelText: s.fieldMode),
              items: [
                for (final m in ModePaiement.values)
                  DropdownMenuItem(value: m, child: Text(m.label(s))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _mode = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reference,
              decoration: InputDecoration(labelText: s.fieldReference2),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('${s.fieldDate} : ${dateFormat.format(_date)}'),
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              DocumentPaiement(
                date: _date,
                montant: parseQty(_montant.text),
                mode: _mode,
                reference: _reference.text,
              ),
            );
          },
          child: Text(s.actionConfirm),
        ),
      ],
    );
  }
}
