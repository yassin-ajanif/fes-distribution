import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/app/app.dart';

Future<void> _tapSection(WidgetTester tester, String title) async {
  await tester.tap(find.text(title.toUpperCase()));
  await tester.pumpAndSettle();
}

Finder _menuText(String text, {required bool mobile}) {
  final menuRoot = mobile ? find.byType(Drawer) : find.byType(ListView).first;
  return find.descendant(of: menuRoot, matching: find.text(text));
}

void main() {
  testWidgets('mobile shell shows drawer menu button', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FesDistributionApp(database: database));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(_menuText('Vendeurs', mobile: true), findsOneWidget);
    expect(_menuText('Bons de charge', mobile: true), findsOneWidget);
    expect(_menuText('Bons de livraison', mobile: true), findsNothing);

    await _tapSection(tester, 'Ventes');
    expect(_menuText('Bons de livraison', mobile: true), findsOneWidget);
    expect(_menuText('Vendeurs', mobile: true), findsNothing);

    await _tapSection(tester, 'Achats');
    expect(_menuText('Bons réception', mobile: true), findsOneWidget);
    expect(_menuText('Bons de livraison', mobile: true), findsNothing);

    await _tapSection(tester, 'Stock & administration');
    expect(_menuText('Stock', mobile: true), findsOneWidget);
    expect(_menuText('Paramètres', mobile: true), findsOneWidget);
    expect(_menuText('Bons réception', mobile: true), findsNothing);
  });

  testWidgets('desktop shell shows permanent sidebar', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FesDistributionApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('DISTRIBUTION'), findsOneWidget);
    expect(_menuText('Bons de charge', mobile: false), findsOneWidget);
    expect(_menuText('Bons de livraison', mobile: false), findsNothing);
    expect(find.byType(Drawer), findsNothing);

    await _tapSection(tester, 'Stock & administration');
    expect(_menuText('Stock', mobile: false), findsOneWidget);
    expect(_menuText('Paramètres', mobile: false), findsOneWidget);
    expect(_menuText('Bons de charge', mobile: false), findsNothing);
  });
}
