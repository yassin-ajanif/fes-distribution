import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/business/services/stock/parametres/app_settings_service.dart';
import 'package:fes_distribution/ui/l10n/app_language.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

final appSettingsServiceProvider = Provider(
  (ref) => AppSettingsService(ref.watch(databaseProvider)),
);

final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _loadFromDatabase();
    return AppLanguage.french;
  }

  Future<void> _loadFromDatabase() async {
    try {
      final code = await ref.read(appSettingsServiceProvider).getUiLanguageCode();
      final next = AppLanguage.fromCode(code);
      if (next != state) state = next;
    } catch (_) {
      // Keep default French if settings cannot be read yet.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    await ref.read(appSettingsServiceProvider).setUiLanguageCode(language.code);
    state = language;
  }
}
