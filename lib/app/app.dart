import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme_choice.dart';
import 'theme/app_themes.dart';
import 'theme/theme_controller.dart';
import '../features/alerts/application/observation_alert_monitor.dart';
import '../features/alerts/data/observation_notification_gateway.dart';

class AstroManagerApp extends ConsumerStatefulWidget {
  const AstroManagerApp({super.key, this.initialLocation});

  final String? initialLocation;

  @override
  ConsumerState<AstroManagerApp> createState() => _AstroManagerAppState();
}

class _AstroManagerAppState extends ConsumerState<AstroManagerApp>
    with WidgetsBindingObserver {
  void _evaluateAlerts() {
    if (!ref.read(observationNotificationGatewayProvider).isSupported) {
      return;
    }
    unawaited(
      ref.read(observationAlertMonitorProvider).checkNow().catchError((
        Object error,
      ) {
        // Offline and unavailable forecasts must never crash app startup.
        debugPrint("Observation alerts check skipped: $error");
        return const ObservationAlertCheckResult(
          sent: 0,
          alreadyDelivered: 0,
          unavailable: 1,
        );
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluateAlerts();
    }
  }

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = createAppRouter(initialLocation: widget.initialLocation);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _evaluateAlerts();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = ref.watch(appThemeProvider);

    final isNight = selectedTheme == AppThemeChoice.night;

    final themeMode = switch (selectedTheme) {
      AppThemeChoice.system => ThemeMode.system,
      AppThemeChoice.light => ThemeMode.light,
      AppThemeChoice.dark => ThemeMode.dark,
      AppThemeChoice.night => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'AstroManager',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,

      theme: AstroThemes.light,
      darkTheme: isNight ? AstroThemes.night : AstroThemes.dark,
      themeMode: themeMode,
    );
  }
}
