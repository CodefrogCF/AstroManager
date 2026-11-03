import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';

import '../data/repositories/drift_app_preferences_repository.dart';
import '../domain/models/app_preferences.dart';
import '../domain/repositories/app_preferences_repository.dart';

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((
  ref,
) {
  final storage = ref.watch(appSettingsRepositoryProvider);

  return DriftAppPreferencesRepository(storage);
});

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
      retry: (retryCount, error) => null,
    );

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  bool _saving = false;

  @override
  Future<AppPreferences> build() {
    return ref.watch(appPreferencesRepositoryProvider).load();
  }

  Future<void> setUnits(MeasurementUnits value) {
    return _update((current) => current.copyWith(units: value));
  }

  Future<void> setClockFormat(ClockFormat value) {
    return _update((current) => current.copyWith(clockFormat: value));
  }

  Future<void> setLanguage(LanguagePreference value) {
    return _update((current) => current.copyWith(language: value));
  }

  Future<void> completeOnboarding() =>
      _update((current) => current.copyWith(onboardingCompleted: true));

  Future<void> _update(AppPreferences Function(AppPreferences) change) async {
    if (_saving) return;

    final previous = state.value;

    if (previous == null || state.isLoading) {
      return;
    }

    final next = change(previous);

    if (next == previous) return;

    _saving = true;
    state = const AsyncLoading();

    try {
      await ref.read(appPreferencesRepositoryProvider).save(next);

      if (ref.mounted) {
        state = AsyncData(next);
      }
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(previous);
      }
      rethrow;
    } finally {
      _saving = false;
    }
  }

  Future<void> restoreDefaults() async {
    if (_saving) return;

    _saving = true;
    final previousState = state;

    state = const AsyncLoading();

    try {
      await ref
          .read(appPreferencesRepositoryProvider)
          .save(AppPreferences.defaults);

      if (ref.mounted) {
        state = const AsyncData(AppPreferences.defaults);
      }
    } catch (_) {
      if (ref.mounted) {
        state = previousState;
      }
      rethrow;
    } finally {
      _saving = false;
    }
  }
}
