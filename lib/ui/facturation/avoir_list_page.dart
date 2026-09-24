import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class AvoirListPage extends StatelessWidget {
  const AvoirListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Avoirs',
      searchHint: 'Rechercher numéro, client…',
      emptyMessage: 'Aucun avoir.\nLe module ventes sera connecté prochainement.',
    );
  }
}
