import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/shell_page.dart';
import 'package:fes_distribution/ui/personnel/bon_charge_edit_page.dart';
import 'package:fes_distribution/ui/personnel/bon_charge_list_page.dart';
import 'package:fes_distribution/ui/personnel/bon_decharge_edit_page.dart';
import 'package:fes_distribution/ui/personnel/bon_decharge_list_page.dart';
import 'package:fes_distribution/ui/personnel/vendeur_detail_page.dart';
import 'package:fes_distribution/ui/facturation/avoir_list_page.dart';
import 'package:fes_distribution/ui/facturation/facture_list_page.dart';
import 'package:fes_distribution/ui/livraison/bl_list_page.dart';
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
        ],
      ),
    ],
  );
}
