import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/ui/common/module_list_page.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

class BlListPage extends ConsumerWidget {
  const BlListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    return ModuleListPage(
      title: s.menuBl,
      searchHint: s.searchBl,
      emptyMessage: s.emptyBl,
    );
  }
}
