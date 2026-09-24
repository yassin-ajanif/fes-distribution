import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class BrListPage extends StatelessWidget {
  const BrListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Bons réception',
      searchHint: 'Rechercher numéro, fournisseur…',
      emptyMessage:
          'Aucun bon réception.\nLe module achats sera connecté prochainement.',
    );
  }
}
