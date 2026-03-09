import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool showIncome;
  final bool accumulated;
  final String voiceLanguage;
  final String currency;
  final String convertFrom;
  final String convertTo;
  final String themeMode; // 'system', 'light', 'dark'

  SettingsState({
    required this.showIncome,
    required this.accumulated,
    required this.voiceLanguage,
    required this.currency,
    required this.convertFrom,
    required this.convertTo,
    required this.themeMode,
  });

  SettingsState copyWith({
    bool? showIncome,
    bool? accumulated,
    String? voiceLanguage,
    String? currency,
    String? convertFrom,
    String? convertTo,
    String? themeMode,
  }) {
    return SettingsState(
      showIncome: showIncome ?? this.showIncome,
      accumulated: accumulated ?? this.accumulated,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      currency: currency ?? this.currency,
      convertFrom: convertFrom ?? this.convertFrom,
      convertTo: convertTo ?? this.convertTo,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  static const _showIncomeKey = 'settings_show_income';
  static const _accumulatedKey = 'settings_accumulated';
  static const _voiceLanguageKey = 'settings_voice_language';
  static const _currencyKey = 'settings_currency';
  static const _convertFromKey = 'settings_convert_from';
  static const _convertToKey = 'settings_convert_to';
  static const _themeModeKey = 'settings_theme_mode';

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          showIncome: _prefs.getBool(_showIncomeKey) ?? true,
          accumulated: _prefs.getBool(_accumulatedKey) ?? false,
          voiceLanguage: _prefs.getString(_voiceLanguageKey) ?? 'es-CO',
          currency: _prefs.getString(_currencyKey) ?? 'COP',
          convertFrom: _prefs.getString(_convertFromKey) ?? 'EUR',
          convertTo: _prefs.getString(_convertToKey) ?? 'COP',
          themeMode: _prefs.getString(_themeModeKey) ?? 'system',
        ));

  void toggleShowIncome(bool value) {
    _prefs.setBool(_showIncomeKey, value);
    state = state.copyWith(showIncome: value);
  }

  void toggleAccumulated(bool value) {
    _prefs.setBool(_accumulatedKey, value);
    state = state.copyWith(accumulated: value);
  }

  void setVoiceLanguage(String lang) {
    _prefs.setString(_voiceLanguageKey, lang);
    state = state.copyWith(voiceLanguage: lang);
  }

  void setCurrency(String currency) {
    _prefs.setString(_currencyKey, currency);
    state = state.copyWith(currency: currency);
  }

  void setConvertFrom(String currency) {
    _prefs.setString(_convertFromKey, currency);
    state = state.copyWith(convertFrom: currency);
  }

  void setConvertTo(String currency) {
    _prefs.setString(_convertToKey, currency);
    state = state.copyWith(convertTo: currency);
  }

  void setThemeMode(String mode) {
    _prefs.setString(_themeModeKey, mode);
    state = state.copyWith(themeMode: mode);
  }
}
