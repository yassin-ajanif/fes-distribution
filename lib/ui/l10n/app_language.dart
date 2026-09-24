import 'package:flutter/material.dart';

enum AppLanguage {
  french('fr'),
  arabic('ar');

  const AppLanguage(this.code);

  final String code;

  Locale get locale => switch (this) {
        AppLanguage.french => const Locale('fr', 'FR'),
        AppLanguage.arabic => const Locale('ar'),
      };

  bool get isRtl => this == AppLanguage.arabic;

  String get displayName => switch (this) {
        AppLanguage.french => 'Français',
        AppLanguage.arabic => 'العربية',
      };

  static const supportedLocales = [
    Locale('fr', 'FR'),
    Locale('ar'),
  ];

  static AppLanguage fromCode(String? code) {
    if (code != null && code.toLowerCase().startsWith('ar')) {
      return AppLanguage.arabic;
    }
    return AppLanguage.french;
  }
}
