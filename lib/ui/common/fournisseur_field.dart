import 'package:flutter/material.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

/// Supplier dropdown with a quick-create button, shared by the achats forms.
/// [locked] disables it (e.g. facture fournisseur with linked BRs).
class FournisseurField extends StatelessWidget {
  const FournisseurField({
    super.key,
    required this.fournisseurs,
    required this.value,
    required this.onChanged,
    required this.onCreate,
    this.locked = false,
    this.lockedHelper,
  });

  final List<Tier> fournisseurs;
  final int? value;
  final ValueChanged<int?> onChanged;
  final VoidCallback onCreate;
  final bool locked;
  final String? lockedHelper;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey('fournisseur-$value-${fournisseurs.length}-$locked'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: s.fieldFournisseur,
              prefixIcon: const Icon(Icons.factory_outlined),
              helperText: locked ? lockedHelper : null,
            ),
            items: [
              for (final f in fournisseurs)
                DropdownMenuItem(
                  value: f.id,
                  child: Text(
                    f.ville.isEmpty ? f.nom : '${f.nom} — ${f.ville}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: locked ? null : onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: s.newFournisseur,
          icon: const Icon(Icons.add_business_outlined),
          onPressed: locked ? null : onCreate,
        ),
      ],
    );
  }
}
