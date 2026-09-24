import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Placeholder list shell for modules not yet wired to the business layer.
class ModuleListPage extends StatelessWidget {
  const ModuleListPage({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    this.onNew,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShellAppBar(title: title),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNew ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title — bientôt disponible')),
              );
            },
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              enabled: false,
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: AppColors.muted),
                    const SizedBox(height: 16),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
