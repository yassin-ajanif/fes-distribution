import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class BlListPage extends StatelessWidget {
  const BlListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Bons de livraison',
      searchHint: 'Rechercher numéro, client, vendeur…',
      emptyMessage: 'Aucun bon de livraison.\nLe module ventes sera connecté prochainement.',
    );
  }
}
