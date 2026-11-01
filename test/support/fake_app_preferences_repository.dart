import 'package:astromanager/features/settings/domain/models/app_preferences.dart';
import 'package:astromanager/features/settings/domain/repositories/app_preferences_repository.dart';

class FakeAppPreferencesRepository implements AppPreferencesRepository {
  AppPreferences preferences = AppPreferences.defaults;

  @override
  Future<AppPreferences> load() async => preferences;

  @override
  Future<void> save(AppPreferences value) async {
    preferences = value;
  }
}
