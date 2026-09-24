import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/app_language.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/locale_provider.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final language = ref.watch(localeProvider);

    return Scaffold(
      appBar: ShellAppBar(title: s.settingsTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.settingsUiLanguage,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.settingsLanguageHint,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<AppLanguage>(
                    segments: AppLanguage.values
                        .map(
                          (lang) => ButtonSegment(
                            value: lang,
                            label: Text(lang.displayName),
                          ),
                        )
                        .toList(),
                    selected: {language},
                    onSelectionChanged: (selection) async {
                      final next = selection.first;
                      await ref.read(localeProvider.notifier).setLanguage(next);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.settingsSaved)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.settings_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 16),
                  Text(
                    s.settingsComingSoon,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
