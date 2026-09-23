import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState extends Equatable {
  final String locale;
  final ThemeMode themeMode;

  const SettingsState({
    this.locale = 'ar',
    this.themeMode = ThemeMode.light,
  });

  SettingsState copyWith({String? locale, ThemeMode? themeMode}) =>
      SettingsState(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  List<Object?> get props => [locale, themeMode];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(super.initialState);

  static const localeKey = 'app_locale';

  static Future<SettingsCubit> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(localeKey);
    return SettingsCubit(SettingsState(locale: _resolveLocale(saved)));
  }

  static String _resolveLocale(String? saved) {
    if (saved == 'ar') return 'ar';
    if (saved == 'en') return 'en';
    final system = ui.PlatformDispatcher.instance.locale.languageCode;
    if (system == 'ar' || system == 'en') return system;
    return 'ar';
  }

  Future<void> toggleLocale() async {
    final next = state.locale == 'ar' ? 'en' : 'ar';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, next);
    emit(state.copyWith(locale: next));
  }

  void toggleTheme() => emit(
        state.copyWith(
          themeMode: state.themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      );
}
