import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Lightweight, hand-rolled localization shim. Avoids the
/// `flutter gen-l10n` codegen step so the build pipeline stays simple,
/// while still letting the app pick up Flutter's [Locale] machinery.
///
/// To add a new language: add a `_translations` map and include the
/// locale in [supportedLocales]. Strings missing from a translation
/// fall back to English, so partial localizations are safe.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('yo'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'TurboGet',
      'download': 'Download',
      'enter_url': 'Enter file URL',
      'no_active_downloads': 'No active downloads',
      'pause': 'Pause',
      'resume': 'Resume',
      'cancel': 'Cancel',
      'history': 'Download History',
      'settings': 'Settings',
    },
    'yo': {
      'app_title': 'TurboGet',
      'download': 'Gbà sílẹ̀',
      'enter_url': 'Tẹ adirẹ́sì fáìlì sí',
      'no_active_downloads': 'Kò sí gbígbà sílẹ̀ tó ń lọ',
      'pause': 'Dáwọ́',
      'resume': 'Tẹ̀síwájú',
      'cancel': 'Fagilé',
      'history': 'Ìtàn ìgbàsílẹ̀',
      'settings': 'Ètò',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _translations[lang]?[key] ?? _translations['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
