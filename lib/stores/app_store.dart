import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_store.g.dart';

class AppStore = AppStoreBase with _$AppStore;

abstract class AppStoreBase with Store {
  static const _keyThemeMode = 'theme_mode';
  static const _keyPreferDeepSeek = 'prefer_deepseek';
  static const _keyDevMode = 'dev_mode';

  @observable
  ThemeMode themeMode = ThemeMode.system;

  @observable
  bool isModelsDownloaded = false;

  @observable
  bool isEmbeddingModelReady = false;

  @observable
  bool isInferenceModelReady = false;

  @observable
  bool isPhi4ModelReady = false;

  @observable
  bool preferPhi4ForText = true; // Default to DeepSeek when available

  @observable
  bool devModeEnabled = false;

  /// Load persisted preferences from SharedPreferences
  @action
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme mode
    final themeModeIndex = prefs.getInt(_keyThemeMode) ?? 0;
    themeMode =
        ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)];

    // DeepSeek preference
    preferPhi4ForText = prefs.getBool(_keyPreferDeepSeek) ?? true;

    // Dev mode
    devModeEnabled = prefs.getBool(_keyDevMode) ?? false;
  }

  @action
  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persistPreference(_keyThemeMode, mode.index);
  }

  @action
  void setModelsDownloaded(bool value) {
    isModelsDownloaded = value;
  }

  @action
  void setEmbeddingModelReady(bool value) {
    isEmbeddingModelReady = value;
  }

  @action
  void setInferenceModelReady(bool value) {
    isInferenceModelReady = value;
  }

  @action
  void setDevModeEnabled(bool value) {
    devModeEnabled = value;
    _persistPreference(_keyDevMode, value);
  }

  @action
  void setPhi4ModelReady(bool value) {
    isPhi4ModelReady = value;
  }

  @action
  void setPreferPhi4ForText(bool value) {
    preferPhi4ForText = value;
    _persistPreference(_keyPreferDeepSeek, value);
  }

  /// Persist a preference to SharedPreferences (async, fire-and-forget)
  void _persistPreference(String key, dynamic value) {
    SharedPreferences.getInstance().then((prefs) {
      if (value is bool) {
        prefs.setBool(key, value);
      } else if (value is int) {
        prefs.setInt(key, value);
      } else if (value is String) {
        prefs.setString(key, value);
      }
    });
  }

  @computed
  bool get isAppReady => isEmbeddingModelReady && isInferenceModelReady;

  /// Should use Phi-4 for text-only queries
  @computed
  bool get shouldUsePhi4 => isPhi4ModelReady && preferPhi4ForText;
}
