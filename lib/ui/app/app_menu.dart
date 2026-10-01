import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/l10n/app_strings.dart';

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

  static const List<AppMenuSectionId> sectionIds = [
    distributionId,
    ventesId,
    achatsId,
    stockAdminId,
  ];

  static const _routesBySection = [
    [
      '/distribution/vendeurs',
      '/distribution/bons-charge',
      '/distribution/bons-decharge',
    ],
    [
      '/ventes/bons-livraison',
      '/ventes/factures',
      '/ventes/avoirs',
      '/ventes/solde-clients',
    ],
    [
      '/achats/bons-reception',
      '/achats/factures-fournisseur',
      '/achats/avoirs-fournisseur',
      '/achats/solde-fournisseurs',
    ],
    [
      '/stock/produits',
      '/stock',
      '/admin/charges',
      '/admin/rapports',
      '/admin/parametres',
    ],
  ];

  static List<AppMenuSection> sections(AppStrings strings) => [
    AppMenuSection(
      title: strings.sectionDistribution,
      items: [
        AppMenuItem(
          label: strings.menuVendeurs,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          route: '/distribution/vendeurs',
        ),
        AppMenuItem(
          label: strings.menuBonCharge,
          icon: Icons.upload_outlined,
          selectedIcon: Icons.upload,
          route: '/distribution/bons-charge',
        ),
        AppMenuItem(
          label: strings.menuBonDecharge,
          icon: Icons.download_outlined,
          selectedIcon: Icons.download,
          route: '/distribution/bons-decharge',
        ),
      ],
    ),
    AppMenuSection(
      title: strings.sectionVentes,
      items: [
        AppMenuItem(
          label: strings.menuBl,
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          route: '/ventes/bons-livraison',
        ),
        AppMenuItem(
          label: strings.menuFactures,
          icon: Icons.description_outlined,
          selectedIcon: Icons.description,
          route: '/ventes/factures',
        ),
        AppMenuItem(
          label: strings.menuAvoirs,
          icon: Icons.undo_outlined,
          selectedIcon: Icons.undo,
          route: '/ventes/avoirs',
        ),
        AppMenuItem(
          label: strings.menuSoldeClients,
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          route: '/ventes/solde-clients',
        ),
      ],
    ),
    AppMenuSection(
      title: strings.sectionAchats,
      items: [
        AppMenuItem(
          label: strings.menuBr,
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          route: '/achats/bons-reception',
        ),
        AppMenuItem(
          label: strings.menuFacturesFournisseur,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          route: '/achats/factures-fournisseur',
        ),
        AppMenuItem(
          label: strings.menuAvoirsFournisseur,
          icon: Icons.undo_outlined,
          selectedIcon: Icons.undo,
          route: '/achats/avoirs-fournisseur',
        ),
        AppMenuItem(
          label: strings.menuSoldeFournisseurs,
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          route: '/achats/solde-fournisseurs',
        ),
      ],
    ),
    AppMenuSection(
      title: strings.sectionStockAdmin,
      items: [
        AppMenuItem(
          label: strings.menuStock,
          icon: Icons.warehouse_outlined,
          selectedIcon: Icons.warehouse,
          route: '/stock',
        ),
        AppMenuItem(
          label: strings.menuProduits,
          icon: Icons.category_outlined,
          selectedIcon: Icons.category,
          route: '/stock/produits',
        ),
        AppMenuItem(
          label: strings.menuCharges,
          icon: Icons.money_off_outlined,
          selectedIcon: Icons.money_off,
          route: '/admin/charges',
        ),
        AppMenuItem(
          label: strings.menuRapports,
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          route: '/admin/rapports',
        ),
        AppMenuItem(
          label: strings.menuParametres,
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          route: '/admin/parametres',
        ),
      ],
    ),
  ];

  static AppMenuSectionId sectionIdForLocation(String location) {
    final route = selectedRoute(location);
    if (route == null) return distributionId;

    for (var i = 0; i < _routesBySection.length; i++) {
      if (_routesBySection[i].contains(route)) return sectionIds[i];
    }
    return distributionId;
  }

  static String? selectedRoute(String location) {
    String? best;
    for (final routes in _routesBySection) {
      for (final route in routes) {
        if (location.startsWith(route) &&
            (best == null || route.length > best.length)) {
          best = route;
        }
      }
    }
    return best;
  }
}
