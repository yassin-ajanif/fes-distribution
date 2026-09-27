import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/services/stock/parametres/app_settings_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  test('persists ui language code', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final service = AppSettingsService(database);
    expect(await service.getUiLanguageCode(), 'fr');

    await service.setUiLanguageCode('ar');
    expect(await service.getUiLanguageCode(), 'ar');
  });
}
