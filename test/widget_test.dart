import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/app/app.dart';

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

    expect(find.text('Vendeurs'), findsWidgets);
    expect(find.text('Bons de charge'), findsOneWidget);
    expect(find.text('Bons de décharge'), findsOneWidget);
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
    expect(find.text('Bons de charge'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });
}
