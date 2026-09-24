import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ShellAppBar(title: 'Paramètres'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                'Paramètres société, TVA, sauvegarde…\n'
                'Le module paramètres sera connecté prochainement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
