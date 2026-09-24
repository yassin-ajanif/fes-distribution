import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

class BrListPage extends ConsumerWidget {
  const BrListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    return ModuleListPage(
      title: s.menuBr,
      searchHint: s.searchBr,
      emptyMessage: s.emptyBr,
    );
  }
}
