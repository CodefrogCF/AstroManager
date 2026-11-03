import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/seven_night_weather_widget.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = ObservingLocation(
  id: 'ch',
  name: 'Observatory',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

const _instance = DashboardWidgetInstance(
  id: 'weather-1',
  typeId: 'seven-night-weather',
  settings: {'maxCloudPercent': '30', 'minClearHours': '2'},
);

void main() {
  testWidgets('no observing site displays an offline-safe empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SevenNightWeatherWidget(location: null, instance: _instance),
          ),
        ),
      ),
    );
    expect(find.textContaining('Add an observing location'), findsOneWidget);
  });

  testWidgets(
    'seven nights, provider attribution and night details are shown',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weatherForecastSnapshotProvider.overrideWith((ref, request) async {
              final now = DateTime.now().toUtc();
              final forecast = WeatherForecast(
                provider: const WeatherProviderMetadata(
                  id: 'stub',
                  name: 'Test Weather',
                  attribution: 'Test forecast attribution',
                ),
                latitudeDegrees: request.latitudeDegrees,
                longitudeDegrees: request.longitudeDegrees,
                issuedAtUtc: now,
                fetchedAtUtc: now,
                hours: List.generate(
                  170,
                  (i) => HourlyWeatherForecast(
                    timeUtc: request.startUtc.add(Duration(hours: i)),
                    totalCloudCoverPercent: const WeatherValue.available(15),
                  ),
                ),
              );
              return WeatherForecastSnapshot(
                forecast: forecast,
                origin: WeatherForecastOrigin.network,
                checkedAtUtc: now,
                isStale: false,
              );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 650,
                height: 320,
                child: SevenNightWeatherWidget(
                  location: _site,
                  instance: _instance,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Weather'), findsOneWidget);
      expect(find.text('Test forecast attribution'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-seven-nights')),
        findsOneWidget,
      );
      // The list is horizontally scrollable; tap the visible first card.
      final tiles = find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('dashboard-night-'),
      );
      expect(tiles, findsWidgets);
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Forecast coverage'), findsOneWidget);
      expect(find.text('Open Night Planner'), findsOneWidget);
    },
  );
  testWidgets('compact weather tiles handle narrow widths and larger text', (
    tester,
  ) async {
    final hostHeight = ValueNotifier<double>(500);
    addTearDown(hostHeight.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherForecastSnapshotProvider.overrideWith((ref, request) async {
            final now = DateTime.now().toUtc();
            return WeatherForecastSnapshot(
              forecast: WeatherForecast(
                provider: const WeatherProviderMetadata(
                  id: 'stub',
                  name: 'Test Weather',
                ),
                latitudeDegrees: request.latitudeDegrees,
                longitudeDegrees: request.longitudeDegrees,
                issuedAtUtc: now,
                fetchedAtUtc: now,
                hours: List.generate(
                  170,
                  (i) => HourlyWeatherForecast(
                    timeUtc: request.startUtc.add(Duration(hours: i)),
                    totalCloudCoverPercent: const WeatherValue.available(15),
                  ),
                ),
              ),
              origin: WeatherForecastOrigin.network,
              checkedAtUtc: now,
              isStale: false,
            );
          }),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: hostHeight,
                  builder: (context, height, child) =>
                      SizedBox(width: 220, height: height, child: child),
                  child: const SevenNightWeatherWidget(
                    location: _site,
                    instance: _instance,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-seven-nights')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // Resized dashboard tiles must remain safe at 200% system text size.
    hostHeight.value = 220;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-seven-nights')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
