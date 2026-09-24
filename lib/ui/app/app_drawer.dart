import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/app_menu.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentLocation});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.sizeOf(context).width * 0.7;

    return Drawer(
      width: drawerWidth,
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
class AppMenuPanel extends StatefulWidget {
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
  State<AppMenuPanel> createState() => _AppMenuPanelState();
}

class _AppMenuPanelState extends State<AppMenuPanel> {
  AppMenuSectionId? _expandedSectionId;

  @override
  void initState() {
    super.initState();
    _expandedSectionId = AppMenu.sectionIdForLocation(widget.currentLocation);
  }

  @override
  void didUpdateWidget(AppMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocation != widget.currentLocation) {
      _expandedSectionId = AppMenu.sectionIdForLocation(widget.currentLocation);
    }
  }

  void _toggleSection(AppMenuSectionId sectionId) {
    setState(() {
      _expandedSectionId =
          _expandedSectionId == sectionId ? null : sectionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final sections = AppMenu.sections(s);
    final selected = AppMenu.selectedRoute(widget.currentLocation);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: AppColors.brand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_shipping,
                      color: Colors.white.withValues(alpha: 0.9), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    s.appTitle,
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
                for (var i = 0; i < sections.length; i++) ...[
                  _MenuSectionHeader(
                    title: sections[i].title,
                    expanded: _expandedSectionId == AppMenu.sectionIds[i],
                    onTap: () => _toggleSection(AppMenu.sectionIds[i]),
                  ),
                  if (_expandedSectionId == AppMenu.sectionIds[i])
                    for (final item in sections[i].items)
                      ListTile(
                        leading: Icon(
                          selected == item.route
                              ? item.selectedIcon
                              : item.icon,
                          color: selected == item.route ? AppColors.brand : null,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            fontWeight: selected == item.route
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color:
                                selected == item.route ? AppColors.brand : null,
                          ),
                        ),
                        selected: selected == item.route,
                        selectedTileColor: AppColors.brandSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          if (selected != item.route) {
                            widget.onNavigate(item.route);
                          }
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

class _MenuSectionHeader extends StatelessWidget {
  const _MenuSectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      leading: Icon(
        expanded ? Icons.arrow_drop_down : Icons.arrow_right,
        color: AppColors.muted,
        size: 22,
      ),
      title: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
      onTap: onTap,
    );
  }
}
