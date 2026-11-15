import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themePreferenceKey = 'appearance.theme';

final themePreferencesProvider = Provider<SharedPreferencesWithCache?>(
  (ref) => null,
);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  Future<void> _pendingSave = Future.value();

  @override
  ThemeMode build() {
    final saved = ref.watch(themePreferencesProvider)?.get(themePreferenceKey);
    return saved == ThemeMode.light.name ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setDarkMode(bool enabled) {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (mode == state) return _pendingSave;
    state = mode;
    final preferences = ref.read(themePreferencesProvider);
    _pendingSave = _pendingSave.then((_) async {
      try {
        await preferences?.setString(themePreferenceKey, mode.name);
      } catch (_) {
        debugPrint('No se pudo guardar el tema de la aplicación.');
      }
    });
    return _pendingSave;
  }
}

Future<SharedPreferencesWithCache?> loadThemePreferences() async {
  try {
    return await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {themePreferenceKey},
      ),
    );
  } catch (_) {
    return null;
  }
}
