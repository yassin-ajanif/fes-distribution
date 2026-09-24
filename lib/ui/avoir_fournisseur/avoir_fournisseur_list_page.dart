import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class AvoirFournisseurListPage extends StatelessWidget {
  const AvoirFournisseurListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Avoirs fournisseur',
      searchHint: 'Rechercher numéro, fournisseur…',
      emptyMessage:
          'Aucun avoir fournisseur.\nLe module achats sera connecté prochainement.',
    );
  }
}
