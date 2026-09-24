import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/app_menu.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentLocation});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: AppMenuPanel(
        currentLocation: currentLocation,
        onNavigate: (route) {
          Navigator.of(context).pop();
          context.go(route);
        },
      ),
    );
  }
}

/// Shared menu panel for drawer (mobile) and permanent sidebar (desktop).
class AppMenuPanel extends StatelessWidget {
  const AppMenuPanel({
    super.key,
    required this.currentLocation,
    required this.onNavigate,
    this.showHeader = true,
  });

  final String currentLocation;
  final void Function(String route) onNavigate;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final selected = AppMenu.selectedRoute(currentLocation);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: AppColors.brand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_shipping, color: Colors.white.withValues(alpha: 0.9), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Fes Distribution',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                for (final section in AppMenu.sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Text(
                      section.title.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                  for (final item in section.items)
                    ListTile(
                      leading: Icon(
                        selected == item.route ? item.selectedIcon : item.icon,
                        color: selected == item.route ? AppColors.brand : null,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight:
                              selected == item.route ? FontWeight.w600 : FontWeight.normal,
                          color: selected == item.route ? AppColors.brand : null,
                        ),
                      ),
                      selected: selected == item.route,
                      selectedTileColor: AppColors.brandSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        if (selected != item.route) onNavigate(item.route);
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
