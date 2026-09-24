import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class ProduitsPage extends StatelessWidget {
  const ProduitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Produits',
      searchHint: 'Rechercher référence, code-barres…',
      emptyMessage:
          'Aucun produit.\nLe catalogue produits sera connecté prochainement.',
    );
  }
}
