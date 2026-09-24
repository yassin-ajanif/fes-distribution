import 'package:drift/drift.dart';
import 'package:fes_distribution/db/app_database.dart';

class AppSettingsService {
  AppSettingsService(this._db);

  final AppDatabase _db;

  static const settingsId = 1;

  Future<String> getUiLanguageCode() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.id.equals(settingsId)))
        .getSingleOrNull();
    return row?.uiLanguage ?? 'fr';
  }

  Future<void> setUiLanguageCode(String code) async {
    await (_db.update(_db.appSettings)..where((t) => t.id.equals(settingsId)))
        .write(AppSettingsCompanion(uiLanguage: Value(code)));
  }
}
