import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/document_lines_table.dart';
import 'package:fes_distribution/ui/common/product_search_field.dart';
import 'package:fes_distribution/ui/l10n/app_language.dart';
import 'package:fes_distribution/ui/l10n/app_strings.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

/// Smallest valid PNG (1x1 transparent) — enough for `Image.memory` to decode
/// without pulling the image package into the test.
final Uint8List _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final lines = [
    DocumentLine(produitId: 1, reference: 'A', designation: 'Blanc', quantite: 1, prixUnitaireHt: 10),
    DocumentLine(produitId: 2, reference: 'B', designation: 'Noir', quantite: 3, prixUnitaireHt: 10),
  ];

  @override
  Widget build(BuildContext context) {
    return DocumentLinesTable(
      lines: lines,
      available: const {1: 5, 2: 2},
      onChanged: (i, l) => setState(() => lines[i] = l),
      onRemoveAt: (i) => setState(() => lines.removeAt(i)),
    );
  }
}

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: StringsScope(
          strings: AppStrings(AppLanguage.french),
          child: const Scaffold(body: SingleChildScrollView(child: _Host())),
        ),
      ),
    );
  }

  testWidgets('typing a quantity keeps the same field focused', (tester) async {
    await pump(tester);
    final qty = find.widgetWithText(TextField, '1');
    await tester.tap(qty);
    await tester.enterText(qty, '1');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '1'), '12');
    await tester.pump();

    final field = tester.widget<TextField>(find.widgetWithText(TextField, '12'));
    expect(field.controller!.text, '12');
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(find.text('Dispo : 5,00'), findsOneWidget);
  });

  testWidgets('removing a line keeps the other line values', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Noir'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Blanc'), findsNothing);
  });

  testWidgets('facture lines: same product from two BLs, no Dispo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StringsScope(
          strings: AppStrings(AppLanguage.french),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DocumentLinesTable(
                lines: [
                  DocumentLine(produitId: 1, reference: 'A', designation: 'BL1', quantite: 2, bonLivraisonId: 10),
                  DocumentLine(produitId: 1, reference: 'A', designation: 'BL2', quantite: 3, bonLivraisonId: 11),
                ],
                onChanged: (_, _) {},
                onRemoveAt: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'BL1'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'BL2'), findsOneWidget);
    expect(find.textContaining('Dispo'), findsNothing);
  });

  testWidgets('purchase lines: unit price is editable', (tester) async {
    DocumentLine? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: StringsScope(
          strings: AppStrings(AppLanguage.french),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DocumentLinesTable(
                lines: [
                  DocumentLine(produitId: 1, reference: 'A', designation: 'Blanc', quantite: 2, prixUnitaireHt: 50, bonReceptionId: 7),
                ],
                editablePrice: true,
                onChanged: (_, l) => changed = l,
                onRemoveAt: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, '50'), '62,5');
    expect(changed!.prixUnitaireHt, 62.5);
    expect(changed!.bonReceptionId, 7);
  });

  Future<void> pumpLines(
    WidgetTester tester, {
    Map<int, Uint8List>? images,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // StringsScope lives above the Navigator in the real app (see app.dart),
    // so dialogs and overlays can read the strings. Mirror that here.
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings(AppLanguage.french),
        child: MaterialApp(
          home: Scaffold(
            body: DocumentLinesTable(
              lines: [
                DocumentLine(produitId: 1, reference: 'A', designation: 'Blanc', quantite: 2),
                DocumentLine(produitId: 2, reference: 'B', designation: 'Noir', quantite: 3),
              ],
              images: images,
              onChanged: (_, _) {},
              onRemoveAt: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a photo button appears only on lines that have a photo', (tester) async {
    await pumpLines(tester, images: {1: _photo});

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('no photo button nor column when the catalog has no photos', (tester) async {
    await pumpLines(tester);

    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.text('Photo'), findsNothing);
  });

  testWidgets('tapping the photo button opens the product image', (tester) async {
    await pumpLines(tester, images: {1: _photo});

    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Blanc')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('product search field builds without an Autocomplete assertion', (
    tester,
  ) async {
    // Autocomplete asserts focusNode and textEditingController are passed
    // together or not at all, so the scan button must own both.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: StringsScope(
          strings: AppStrings(AppLanguage.french),
          child: const MaterialApp(
            home: Scaffold(
              body: ProductSearchField(produits: [], onSelected: _ignore),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}

void _ignore(Produit _) {}
