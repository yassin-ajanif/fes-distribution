import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.contains('/bons-charge')) return 1;
    if (location.contains('/bons-decharge')) return 2;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/distribution/vendeurs');
      case 1:
        context.go('/distribution/bons-charge');
      case 2:
        context.go('/distribution/bons-decharge');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    final mobile = isMobile(context);

    if (mobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) => _onDestinationSelected(context, index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Vendeurs',
            ),
            NavigationDestination(
              icon: Icon(Icons.upload_outlined),
              selectedIcon: Icon(Icons.upload),
              label: 'Charge',
            ),
            NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download),
              label: 'Décharge',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isDesktop(context),
            selectedIndex: selected,
            onDestinationSelected: (index) => _onDestinationSelected(context, index),
            leading: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.local_shipping, color: AppColors.brand, size: 32),
                  if (isDesktop(context)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Distribution',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Vendeurs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.upload_outlined),
                selectedIcon: Icon(Icons.upload),
                label: Text('Bon charge'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: Text('Bon décharge'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
