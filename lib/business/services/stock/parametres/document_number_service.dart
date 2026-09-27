import 'package:fes_distribution/business/helpers/document_numbering.dart';
import 'package:fes_distribution/db/app_database.dart';

class DocumentNumberService {
  DocumentNumberService(this._db);

  final AppDatabase _db;

  Future<String> nextBonCharge() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.bonsCharge).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'BCH',
      );

  Future<String> nextBonDecharge() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.bonsDecharge).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'BDH',
      );

  Future<String> nextBonLivraison() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.bonsLivraison).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'BL',
      );

  Future<String> nextFacture() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.factures).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'FAC',
      );

  Future<String> nextAvoir() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.avoirs).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'AVO',
      );

  Future<String> nextBonReception() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.bonsReception).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'BR',
      );

  Future<String> nextFactureFournisseur() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.facturesFournisseurs).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'FAF',
      );

  Future<String> nextAvoirFournisseur() => _nextFromDb(
        loadNumeros: () async {
          final rows = await _db.select(_db.avoirsFournisseurs).get();
          return rows.map((r) => r.numero).toList();
        },
        prefix: 'AVF',
      );

  Future<String> _nextFromDb({
    required Future<List<String>> Function() loadNumeros,
    required String prefix,
  }) async {
    final year = DateTime.now().year;
    final numeros = await loadNumeros();
    final dbMax = DocumentNumbering.maxSequenceFromNumeros(numeros, prefix, year);
    final next = DocumentNumbering.resolveNextSequence(dbMax, 0);
    return DocumentNumbering.generate(prefix, next - 1, year);
  }
}
