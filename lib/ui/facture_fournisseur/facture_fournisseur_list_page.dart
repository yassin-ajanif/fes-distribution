import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class FactureFournisseurListPage extends StatelessWidget {
  const FactureFournisseurListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Factures fournisseur',
      searchHint: 'Rechercher numéro, fournisseur…',
      emptyMessage:
          'Aucune facture fournisseur.\nLe module achats sera connecté prochainement.',
    );
  }
}
