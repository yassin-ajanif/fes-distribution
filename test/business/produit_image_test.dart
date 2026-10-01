import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fes_distribution/business/models/produit_input.dart';
import 'package:fes_distribution/business/services/stock/produits/produit_image_service.dart';
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

  group('ProduitImageService', () {
    const imageService = ProduitImageService();

    test('downscales a large landscape photo to 600 px wide', () async {
      final big = img.Image(width: 1600, height: 1200);
      img.fill(big, color: img.ColorRgb8(120, 30, 200));
      final raw = Uint8List.fromList(img.encodeJpg(big, quality: 95));

      final decoded = img.decodeImage(await imageService.prepare(raw))!;

      expect(decoded.width, 600);
      expect(decoded.height, 450);
    });

    test('downscales a large portrait photo to 600 px tall', () async {
      final big = img.Image(width: 900, height: 1500);
      img.fill(big, color: img.ColorRgb8(10, 200, 90));
      final raw = Uint8List.fromList(img.encodeJpg(big, quality: 95));

      final decoded = img.decodeImage(await imageService.prepare(raw))!;

      expect(decoded.width, 360);
      expect(decoded.height, 600);
    });

    test('stays at the configured 600 px cap', () {
      expect(ProduitImageService.maxDimension, 600);
      expect(ProduitImageService.jpegQuality, 75);
    });

    test('returns an already-small image untouched', () async {
      final small = img.Image(width: 400, height: 300);
      final raw = Uint8List.fromList(img.encodeJpg(small, quality: 90));

      final out = await imageService.prepare(raw);

      expect(identical(out, raw), isTrue);
    });
  });
}
