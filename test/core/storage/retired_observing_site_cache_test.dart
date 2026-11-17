import 'package:astromanager/core/storage/retired_observing_site_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _Preferences extends Fake implements SharedPreferencesAsync {
  final keys = {
    'astromanager.light-pollution.v1.first',
    'astromanager.light-pollution.v1.second',
    'astromanager.terrain.v1.keep',
    'astromanager.weather.v1.keep',
    'theme',
  };
  final clearCalls = <Set<String>?>[];

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async =>
      allowList == null ? keys.toSet() : keys.intersection(allowList);

  @override
  Future<void> clear({Set<String>? allowList}) async {
    clearCalls.add(allowList);
    if (allowList == null) {
      keys.clear();
    } else {
      keys.removeAll(allowList);
    }
  }
}

void main() {
  test('clears only the retired cache and can run again safely', () async {
    final preferences = _Preferences();
    await clearRetiredObservingSiteCache(preferences);
    await clearRetiredObservingSiteCache(preferences);
    expect(preferences.clearCalls, hasLength(1));
    expect(preferences.keys, {
      'astromanager.terrain.v1.keep',
      'astromanager.weather.v1.keep',
      'theme',
    });
  });
}
