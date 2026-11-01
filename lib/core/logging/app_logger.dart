import 'dart:developer' as developer;

enum AppLogLevel { info, warning, error }

abstract final class AppLogger {
  static const _loggerName = 'AstroManager';

  static void info(String event) {
    _write(AppLogLevel.info, event);
  }

  static void warning(String event) {
    _write(AppLogLevel.warning, event);
  }

  static void error(String event) {
    _write(AppLogLevel.error, event);
  }

  static void _write(AppLogLevel level, String event) {
    final severity = switch (level) {
      AppLogLevel.info => 800,
      AppLogLevel.warning => 900,
      AppLogLevel.error => 1000,
    };

    developer.log(event, name: _loggerName, level: severity);
  }
}
