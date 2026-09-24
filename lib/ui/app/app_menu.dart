import 'package:flutter/material.dart';

/// Central menu definition — add future modules here.
class AppMenuItem {
  const AppMenuItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

class AppMenuSection {
  const AppMenuSection({required this.title, required this.items});

  final String title;
  final List<AppMenuItem> items;
}

class AppMenu {
  AppMenu._();

  static const distribution = AppMenuSection(
    title: 'Distribution',
    items: [
      AppMenuItem(
        label: 'Vendeurs',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        route: '/distribution/vendeurs',
      ),
      AppMenuItem(
        label: 'Bons de charge',
        icon: Icons.upload_outlined,
        selectedIcon: Icons.upload,
        route: '/distribution/bons-charge',
      ),
      AppMenuItem(
        label: 'Bons de décharge',
        icon: Icons.download_outlined,
        selectedIcon: Icons.download,
        route: '/distribution/bons-decharge',
      ),
    ],
  );

  static const ventes = AppMenuSection(
    title: 'Ventes',
    items: [
      AppMenuItem(
        label: 'Bons de livraison',
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        route: '/ventes/bons-livraison',
      ),
      AppMenuItem(
        label: 'Factures',
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
        route: '/ventes/factures',
      ),
      AppMenuItem(
        label: 'Avoirs',
        icon: Icons.undo_outlined,
        selectedIcon: Icons.undo,
        route: '/ventes/avoirs',
      ),
    ],
  );

  static const List<AppMenuSection> sections = [distribution, ventes];

  static String? selectedRoute(String location) {
    for (final section in sections) {
      for (final item in section.items) {
        if (location.startsWith(item.route)) return item.route;
      }
    }
    return null;
  }
}
