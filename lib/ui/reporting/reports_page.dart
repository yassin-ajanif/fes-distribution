import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleListPage(
      title: 'Rapports',
      searchHint: 'Rechercher un rapport…',
      emptyMessage:
          'Aucun rapport disponible.\nLe module rapports sera connecté prochainement.',
    );
  }
}
