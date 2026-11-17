import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

/// Discard derived data left by earlier versions on this device.
Future<void> clearRetiredObservingSiteCache(
  SharedPreferencesAsync preferences,
) async {
  try {
    final keys = await preferences.getKeys();
    final retiredKeys = keys
        .where((key) => key.startsWith('astromanager.light-pollution.v1.'))
        .toSet();
    if (retiredKeys.isNotEmpty) {
      await preferences.clear(allowList: retiredKeys);
    }
  } catch (_) {
    AppLogger.warning('retired_observing_site_cache_cleanup_failed');
  }
}
