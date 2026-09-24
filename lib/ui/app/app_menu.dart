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

enum AppMenuSectionId { distribution, ventes, achats, stockAdmin }

class AppMenu {
  AppMenu._();

  static const distributionId = AppMenuSectionId.distribution;
  static const ventesId = AppMenuSectionId.ventes;
  static const achatsId = AppMenuSectionId.achats;
  static const stockAdminId = AppMenuSectionId.stockAdmin;

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

  static const achats = AppMenuSection(
    title: 'Achats',
    items: [
      AppMenuItem(
        label: 'Bons réception',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        route: '/achats/bons-reception',
      ),
      AppMenuItem(
        label: 'Factures fournisseur',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        route: '/achats/factures-fournisseur',
      ),
      AppMenuItem(
        label: 'Avoirs fournisseur',
        icon: Icons.undo_outlined,
        selectedIcon: Icons.undo,
        route: '/achats/avoirs-fournisseur',
      ),
    ],
  );

  static const stockAdmin = AppMenuSection(
    title: 'Stock & administration',
    items: [
      AppMenuItem(
        label: 'Stock',
        icon: Icons.warehouse_outlined,
        selectedIcon: Icons.warehouse,
        route: '/stock',
      ),
      AppMenuItem(
        label: 'Produits',
        icon: Icons.category_outlined,
        selectedIcon: Icons.category,
        route: '/stock/produits',
      ),
      AppMenuItem(
        label: 'Rapports',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        route: '/admin/rapports',
      ),
      AppMenuItem(
        label: 'Paramètres',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        route: '/admin/parametres',
      ),
    ],
  );

  static const List<AppMenuSection> sections = [
    distribution,
    ventes,
    achats,
    stockAdmin,
  ];

  static const List<AppMenuSectionId> sectionIds = [
    distributionId,
    ventesId,
    achatsId,
    stockAdminId,
  ];

  static AppMenuSectionId sectionIdForLocation(String location) {
    final route = selectedRoute(location);
    if (route == null) return distributionId;

    for (var i = 0; i < sections.length; i++) {
      for (final item in sections[i].items) {
        if (item.route == route) return sectionIds[i];
      }
    }
    return distributionId;
  }

  static String? selectedRoute(String location) {
    String? best;
    for (final section in sections) {
      for (final item in section.items) {
        if (location.startsWith(item.route) &&
            (best == null || item.route.length > best.length)) {
          best = item.route;
        }
      }
    }
    return best;
  }
}
