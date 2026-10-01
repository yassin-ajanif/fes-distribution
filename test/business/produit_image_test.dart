import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/produit_input.dart';
import 'package:fes_distribution/business/services/stock/produits/produit_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late ProduitService service;

  final photo = Uint8List.fromList([1, 2, 3, 4]);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ProduitService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create stores the photo, update without one keeps it', () async {
    final id = await service.create(
      ProduitInput(
        reference: 'P-1',
        designation: 'Peinture blanche',
        codeBarre: '6111234567890',
        imageData: photo,
      ),
    );
    expect((await service.getById(id))!.imageData, photo);

    // A plain edit (no photo in the payload) must not wipe the stored photo.
    await service.update(
      id,
      const ProduitInput(reference: 'P-1', designation: 'Peinture blanc cassé'),
    );
    final updated = (await service.getById(id))!;
    expect(updated.imageData, photo);
    expect(updated.designation, 'Peinture blanc cassé');
  });

  test('update replaces the photo when new bytes are supplied', () async {
    final id = await service.create(
      ProduitInput(reference: 'P-1', designation: 'Peinture', imageData: photo),
    );

    final replacement = Uint8List.fromList([9, 9, 9]);
    await service.update(
      id,
      ProduitInput(
        reference: 'P-1',
        designation: 'Peinture',
        imageData: replacement,
      ),
    );

    expect((await service.getById(id))!.imageData, replacement);
  });

  test('clearImage drops the stored photo', () async {
    final id = await service.create(
      ProduitInput(reference: 'P-1', designation: 'Peinture', imageData: photo),
    );

    await service.update(
      id,
      const ProduitInput(
        reference: 'P-1',
        designation: 'Peinture',
        clearImage: true,
      ),
    );

    expect((await service.getById(id))!.imageData, isNull);
  });

  test(
    'findByCodeBarre matches the barcode then falls back to reference',
    () async {
      final id = await service.create(
        const ProduitInput(
          reference: 'REF-42',
          designation: 'Enduit',
          codeBarre: '6111234567890',
        ),
      );

      expect((await service.findByCodeBarre('6111234567890'))!.id, id);
      expect((await service.findByCodeBarre('REF-42'))!.id, id);
      expect(await service.findByCodeBarre('unknown'), isNull);
      expect(await service.findByCodeBarre('  '), isNull);
    },
  );

  test('a barcode cannot be shared by two products', () async {
    await service.create(
      const ProduitInput(
        reference: 'P-1',
        designation: 'Un',
        codeBarre: '6111234567890',
      ),
    );

    await expectLater(
      service.create(
        const ProduitInput(
          reference: 'P-2',
          designation: 'Deux',
          codeBarre: '6111234567890',
        ),
      ),
      throwsStateError,
    );
  });
}
