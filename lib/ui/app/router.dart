import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/shell_page.dart';
import 'package:fes_distribution/ui/personnel/bon_charge_edit_page.dart';
import 'package:fes_distribution/ui/personnel/bon_charge_list_page.dart';
import 'package:fes_distribution/ui/personnel/bon_decharge_edit_page.dart';
import 'package:fes_distribution/ui/personnel/bon_decharge_list_page.dart';
import 'package:fes_distribution/ui/personnel/vendeur_detail_page.dart';
import 'package:fes_distribution/ui/avoir_fournisseur/avoir_fournisseur_edit_page.dart';
import 'package:fes_distribution/ui/avoir_fournisseur/avoir_fournisseur_list_page.dart';
import 'package:fes_distribution/ui/facturation/avoir_edit_page.dart';
import 'package:fes_distribution/ui/facturation/avoir_list_page.dart';
import 'package:fes_distribution/ui/facturation/facture_edit_page.dart';
import 'package:fes_distribution/ui/facturation/facture_list_page.dart';
import 'package:fes_distribution/ui/facture_fournisseur/facture_fournisseur_edit_page.dart';
import 'package:fes_distribution/ui/facture_fournisseur/facture_fournisseur_list_page.dart';
import 'package:fes_distribution/ui/livraison/bl_edit_page.dart';
import 'package:fes_distribution/ui/livraison/bl_list_page.dart';
import 'package:fes_distribution/ui/reception/br_edit_page.dart';
import 'package:fes_distribution/ui/reception/br_list_page.dart';
import 'package:fes_distribution/ui/reporting/reports_page.dart';
import 'package:fes_distribution/ui/settings/settings_page.dart';
import 'package:fes_distribution/ui/stock/produit_edit_page.dart';
import 'package:fes_distribution/ui/stock/produits_page.dart';
import 'package:fes_distribution/ui/stock/stock_page.dart';
import 'package:fes_distribution/ui/stock/stock_transfer_page.dart';
import 'package:fes_distribution/ui/ventes/client_balance_detail_page.dart';
import 'package:fes_distribution/ui/ventes/client_balance_page.dart';
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
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const BlEditPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return BlEditPage(blId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/ventes/factures',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FactureListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final bl = state.uri.queryParameters['bl'];
                  return FactureEditPage(
                    fromBlId: bl == null ? null : int.tryParse(bl),
                  );
                },
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return FactureEditPage(factureId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/ventes/avoirs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AvoirListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final facture = state.uri.queryParameters['facture'];
                  return AvoirEditPage(
                    fromFactureId: facture == null ? null : int.tryParse(facture),
                  );
                },
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AvoirEditPage(avoirId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/ventes/solde-clients',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClientBalancePage(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ClientBalanceDetailPage(clientId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/achats/bons-reception',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BrListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const BrEditPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return BrEditPage(brId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/achats/factures-fournisseur',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FactureFournisseurListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final br = state.uri.queryParameters['br'];
                  return FactureFournisseurEditPage(
                    fromBrId: br == null ? null : int.tryParse(br),
                  );
                },
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return FactureFournisseurEditPage(factureId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/achats/avoirs-fournisseur',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AvoirFournisseurListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AvoirFournisseurEditPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AvoirFournisseurEditPage(avoirId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/stock/produits',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProduitsPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const ProduitEditPage(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ProduitEditPage(produitId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/stock',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StockPage(),
            ),
            routes: [
              GoRoute(
                path: 'transfert',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const StockTransferPage(),
              ),
            ],
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
