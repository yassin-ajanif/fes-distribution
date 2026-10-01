import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/produit_input.dart';
import 'package:fes_distribution/business/services/stock/produits/produit_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late ProduitService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = ProduitService(db);
    for (var i = 1; i <= 25; i++) {
      await service.create(
        ProduitInput(
          reference: 'REF-${i.toString().padLeft(3, '0')}',
          designation: 'Produit $i',
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('a page returns the requested slice in reference order', () async {
    final page = await service.listCatalog(limit: 5, offset: 5);
    expect(page.map((p) => p.reference), [
      'REF-006',
      'REF-007',
      'REF-008',
      'REF-009',
      'REF-010',
    ]);
  });

  test('pages are contiguous and the last page is short', () async {
    final first = await service.listCatalog(limit: 10);
    final second = await service.listCatalog(limit: 10, offset: 10);
    final third = await service.listCatalog(limit: 10, offset: 20);
    final past = await service.listCatalog(limit: 10, offset: 25);

    expect(first.length, 10);
    expect(second.length, 10);
    expect(third.length, 5);
    expect(past, isEmpty);

    final references = [...first, ...second, ...third]
        .map((p) => p.reference)
        .toList();
    expect(references.toSet().length, 25, reason: 'no row repeats');
  });

  test('pagination also applies to a search filter', () async {
    await service.create(
      const ProduitInput(reference: 'ZZZ-1', designation: 'Unique'),
    );
    final filtered = await service.listCatalog(search: 'ZZZ', limit: 10);
    expect(filtered.map((p) => p.reference), ['ZZZ-1']);
  });

  test('an unbounded call still returns everything', () async {
    expect((await service.listCatalog()).length, 25);
  });
}
