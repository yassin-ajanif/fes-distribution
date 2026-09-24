import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/app/app.dart';

void main() {
  testWidgets('mobile shell shows bottom navigation', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FesDistributionApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Vendeurs'), findsWidgets);
    expect(find.text('Charge'), findsOneWidget);
    expect(find.text('Décharge'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('desktop shell shows navigation rail', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FesDistributionApp(database: database));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
