import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// IANA identifiers backed by the same database used in site validation.
/// No user-supplied free text is accepted by the location editor.
abstract final class IanaTimeZones {
  static List<String>? _all;

  static List<String> get all {
    final existing = _all;
    if (existing != null) {
      return existing;
    }
    tz_data.initializeTimeZones();
    final identifiers = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return _all = List<String>.unmodifiable(identifiers);
  }
}
