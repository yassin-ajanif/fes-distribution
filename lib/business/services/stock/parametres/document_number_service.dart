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
