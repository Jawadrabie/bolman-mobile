import 'package:flutter/material.dart';

import 'locales/ar.dart';
import 'locales/en.dart';
import 'status_labels.dart';

export 'status_labels.dart';

class L10n {
  final Locale locale;

  L10n(this.locale);

  static const delegate = _L10nDelegate();

  static L10n of(BuildContext context) => Localizations.of<L10n>(context, L10n)!;

  String get languageCode => locale.languageCode;

  Map<String, String> get _map => languageCode == 'en' ? enMessages : arMessages;

  String t(String key, [Map<String, String> params = const {}]) {
    var text = _map[key] ?? arMessages[key] ?? key;
    params.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  String status(String value) => translateStatus(value, languageCode);

  String money(num value) {
    final formatted = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
    return '$formatted ${t('common.currency')}';
  }
}

extension Tr on BuildContext {
  L10n get l10n => L10n.of(this);

  String tr(String key, [Map<String, String> params = const {}]) => l10n.t(key, params);

  String trStatus(String value) => l10n.status(value);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<L10n> old) => false;
}
