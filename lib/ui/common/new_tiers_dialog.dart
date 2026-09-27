import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

/// Quick client creation from a sales document. Pops the created [Tier].
Future<Tier?> showNewClientDialog(BuildContext context) => showDialog<Tier>(
      context: context,
      builder: (_) => const _NewTiersDialog(fournisseur: false),
    );

/// Quick supplier creation from a purchase document. Pops the created [Tier].
Future<Tier?> showNewFournisseurDialog(BuildContext context) =>
    showDialog<Tier>(
      context: context,
      builder: (_) => const _NewTiersDialog(fournisseur: true),
    );

class _NewTiersDialog extends ConsumerStatefulWidget {
  const _NewTiersDialog({required this.fournisseur});

  final bool fournisseur;

  @override
  ConsumerState<_NewTiersDialog> createState() => _NewTiersDialogState();
}

class _NewTiersDialogState extends ConsumerState<_NewTiersDialog> {
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

  String get _title =>
      widget.fournisseur ? context.s.newFournisseur : context.s.newClient;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tiers = ref.read(tiersServiceProvider);
      final created = widget.fournisseur
          ? await tiers.createFournisseur(
              nom: _nom.text,
              telephone: _telephone.text,
              ville: _ville.text,
            )
          : await tiers.createClient(
              nom: _nom.text,
              telephone: _telephone.text,
              ville: _ville.text,
            );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: _title, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(_title),
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
