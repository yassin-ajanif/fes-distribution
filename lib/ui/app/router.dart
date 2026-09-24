import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/shell_page.dart';
import 'package:fes_distribution/ui/personnel/bon_charge_edit_page.dart';
import 'package:fes_distribution/ui/personnel/bon_charge_list_page.dart';
import 'package:fes_distribution/ui/personnel/bon_decharge_edit_page.dart';
import 'package:fes_distribution/ui/personnel/bon_decharge_list_page.dart';
import 'package:fes_distribution/ui/personnel/vendeur_detail_page.dart';
import 'package:fes_distribution/ui/avoir_fournisseur/avoir_fournisseur_list_page.dart';
import 'package:fes_distribution/ui/facturation/avoir_list_page.dart';
import 'package:fes_distribution/ui/facturation/facture_list_page.dart';
import 'package:fes_distribution/ui/facture_fournisseur/facture_fournisseur_list_page.dart';
import 'package:fes_distribution/ui/livraison/bl_list_page.dart';
import 'package:fes_distribution/ui/reception/br_list_page.dart';
import 'package:fes_distribution/ui/reporting/reports_page.dart';
import 'package:fes_distribution/ui/settings/settings_page.dart';
import 'package:fes_distribution/ui/stock/produits_page.dart';
import 'package:fes_distribution/ui/stock/stock_page.dart';
import 'package:fes_distribution/ui/personnel/vendeurs_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/distribution/vendeurs',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShellPage(child: child),
        routes: [
          GoRoute(
            path: '/distribution/vendeurs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendeursPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const VendeurDetailPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return VendeurDetailPage(userId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/distribution/bons-charge',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BonChargeListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const BonChargeEditPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return BonChargeEditPage(bonId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/distribution/bons-decharge',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BonDechargeListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const BonDechargeEditPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return BonDechargeEditPage(bonId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/ventes/bons-livraison',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BlListPage(),
            ),
          ),
          GoRoute(
            path: '/ventes/factures',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FactureListPage(),
            ),
          ),
          GoRoute(
            path: '/ventes/avoirs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AvoirListPage(),
            ),
          ),
          GoRoute(
            path: '/achats/bons-reception',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BrListPage(),
            ),
          ),
          GoRoute(
            path: '/achats/factures-fournisseur',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FactureFournisseurListPage(),
            ),
          ),
          GoRoute(
            path: '/achats/avoirs-fournisseur',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AvoirFournisseurListPage(),
            ),
          ),
          GoRoute(
            path: '/stock/produits',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProduitsPage(),
            ),
          ),
          GoRoute(
            path: '/stock',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StockPage(),
            ),
          ),
          GoRoute(
            path: '/admin/rapports',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReportsPage(),
            ),
          ),
          GoRoute(
            path: '/admin/parametres',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
