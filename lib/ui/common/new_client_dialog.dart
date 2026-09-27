import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

/// Quick client creation from a sales document. Pops the created [Tier].
Future<Tier?> showNewClientDialog(BuildContext context) =>
    showDialog<Tier>(context: context, builder: (_) => const _NewClientDialog());

class _NewClientDialog extends ConsumerStatefulWidget {
  const _NewClientDialog();

  @override
  ConsumerState<_NewClientDialog> createState() => _NewClientDialogState();
}

class _NewClientDialogState extends ConsumerState<_NewClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _ville = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _ville.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = await ref.read(tiersServiceProvider).createClient(
            nom: _nom.text,
            telephone: _telephone.text,
            ville: _ville.text,
          );
      if (mounted) Navigator.of(context).pop(client);
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: context.s.newClient, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.newClient),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nom,
              autofocus: true,
              decoration: InputDecoration(labelText: s.fieldName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telephone,
              decoration: InputDecoration(labelText: s.fieldTelephone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ville,
              decoration: InputDecoration(labelText: s.fieldVille),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(s.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(s.actionSave),
        ),
      ],
    );
  }
}
