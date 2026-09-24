import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class FactureListPage extends StatelessWidget {
  const FactureListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Factures',
      searchHint: 'Rechercher numéro, client…',
      emptyMessage: 'Aucune facture.\nLe module ventes sera connecté prochainement.',
    );
  }
}
