import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class StockPage extends StatelessWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Stock',
      searchHint: 'Rechercher référence, désignation…',
      emptyMessage:
          'Aucun produit en stock.\nLe module stock sera connecté prochainement.',
    );
  }
}
