import 'dart:async';

import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/domain/seven_night_weather.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/seven_night_weather_widget.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';
import 'package:astromanager/features/weather/domain/repositories/weather_cache_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/weather_fakes.dart';

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

const _offline = WeatherException(
  type: WeatherErrorType.network,
  message: 'Offline',
);

WeatherForecast _mockForecast(
  WeatherForecastRequest request,
  DateTime fetchedAt,
  double cloudCover,
) => WeatherForecast(
  provider: const WeatherProviderMetadata(id: 'mock', name: 'Mock'),
  latitudeDegrees: request.latitudeDegrees,
  longitudeDegrees: request.longitudeDegrees,
  issuedAtUtc: fetchedAt,
  fetchedAtUtc: fetchedAt,
  hours: List.generate(
    request.endUtc.difference(request.startUtc).inHours,
    (index) => HourlyWeatherForecast(
      timeUtc: request.startUtc.add(Duration(hours: index)),
      totalCloudCoverPercent: WeatherValue.available(cloudCover),
    ),
  ),
);

Future<void> _pumpControlledForecast(
  WidgetTester tester,
  ControlledWeatherProvider provider,
  MemoryWeatherCache cache, {
  Widget forecast = const SevenNightWeatherWidget(
    location: _site,
    instance: _instance,
  ),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherProviderProvider.overrideWithValue(provider),
        weatherCacheRepositoryProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(home: Scaffold(body: forecast)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the view switches the tile and details using the same forecast',
    (tester) async {
      final provider = ControlledWeatherProvider(
        (request) async => _mockForecast(request, DateTime.now().toUtc(), 10),
      );
      await _pumpControlledForecast(tester, provider, MemoryWeatherCache());
      final request = provider.requests.single;
      final periods = SevenNightWeatherAggregator.upcomingPeriods(
        location: _site,
        nowUtc: request.startUtc.add(const Duration(hours: 12)),
      );
      final firstDay = periods.days.first;
      expect(request.startUtc.isAtSameMomentAs(firstDay.dayStartUtc), isTrue);
      final dayHours = '${firstDay.civilDayLength.inHours}h';

      final selector = find.byKey(const ValueKey('clear-sky-view'));
      Finder selected(String label) =>
          find.descendant(of: selector, matching: find.text(label));
      final firstTile = find
          .byWidgetPredicate(
            (widget) =>
                widget is InkWell &&
                widget.key.toString().contains('dashboard-night-'),
          )
          .first;

      expect(selected('Night only'), findsOneWidget);
      await tester.tap(firstTile);
      await tester.pumpAndSettle();
      expect(find.textContaining('Astronomical darkness:'), findsOneWidget);
      expect(find.text('Longest clear period: $dayHours'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full day'));
      await tester.pumpAndSettle();
      expect(selected('Full day'), findsOneWidget);
      expect(
        find.descendant(of: firstTile, matching: find.text('$dayHours clear')),
        findsOneWidget,
      );

      await tester.tap(firstTile);
      await tester.pumpAndSettle();
      expect(find.text('Local calendar day: $dayHours'), findsOneWidget);
      expect(find.text('Qualifying clear hours: $dayHours'), findsOneWidget);
      expect(find.text('Longest clear period: $dayHours'), findsOneWidget);
      expect(
        find.text('Forecast coverage: $dayHours / $dayHours'),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night only'));
      await tester.pumpAndSettle();
      expect(selected('Night only'), findsOneWidget);
      expect(
        find.descendant(of: firstTile, matching: find.text('$dayHours clear')),
        findsNothing,
      );
      expect(provider.calls, 1);
    },
  );

  testWidgets(
    'a failed wider request still shows an existing cached night forecast',
    (tester) async {
      final now = DateTime.now().toUtc();
      final nights = SevenNightWeatherAggregator.upcomingNights(
        location: _site,
        nowUtc: now,
      );
      final legacyRequest = WeatherForecastRequest(
        latitudeDegrees: _site.latitude,
        longitudeDegrees: _site.longitude,
        startUtc: DateTime.utc(now.year, now.month, now.day, now.hour),
        endUtc: nights.last.nightEndUtc,
      );
      final provider = ControlledWeatherProvider(
        (_) async => throw const WeatherException(
          type: WeatherErrorType.invalidResponse,
          message: 'Forecast unavailable',
        ),
      );
      final cache = MemoryWeatherCache();
      await cache.write(
        WeatherCacheKey(
          providerId: provider.metadata.id,
          request: legacyRequest,
        ),
        _mockForecast(
          legacyRequest,
          now.subtract(const Duration(hours: 2)),
          10,
        ),
      );

      await _pumpControlledForecast(tester, provider, cache);

      expect(provider.requests.single, isNot(legacyRequest));
      expect(find.text('Night only'), findsOneWidget);
      expect(find.text('Offline cache'), findsOneWidget);
      expect(find.text('Cloud cover: 10%'), findsWidgets);
    },
  );

  testWidgets('manual refresh bypasses a fresh cache and updates in place', (
    tester,
  ) async {
    final originalTime = DateTime.now().toUtc().subtract(
      const Duration(minutes: 37),
    );
    final provider = ControlledWeatherProvider(
      (request) async => _mockForecast(request, originalTime, 75),
    );
    final cache = MemoryWeatherCache();
    await _pumpControlledForecast(tester, provider, cache);
    final original = cache.values.entries.single;
    expect(
      const WeatherCachePolicy().isFresh(original.value, DateTime.now()),
      isTrue,
    );
    expect(find.text('· 37m'), findsOneWidget);
    expect(find.text('Cloud cover: 75%'), findsWidgets);

    final refresh = find.byTooltip('Refresh forecast');
    final pending = Completer<WeatherForecast>();
    provider.respond = (_) => pending.future;
    await tester.tap(refresh);
    await tester.tap(refresh);
    await tester.pump();

    expect(provider.calls, 2);
    final request = provider.requests.last;
    expect(request, original.key.request);
    expect(request.latitudeDegrees, _site.latitude);
    expect(request.longitudeDegrees, _site.longitude);
    expect(find.text('Updating'), findsOneWidget);
    expect(find.text('· 37m'), findsOneWidget);
    expect(find.text('Cloud cover: 75%'), findsWidgets);

    pending.complete(_mockForecast(request, DateTime.now().toUtc(), 20));
    await tester.pumpAndSettle();

    expect(find.text('Updating'), findsNothing);
    expect(find.text('· 0m'), findsOneWidget);
    expect(find.text('Cloud cover: 20%'), findsWidgets);
    expect(find.text('Cloud cover: 75%'), findsNothing);

    // A failed cache write can leave an older copy on disk.
    cache.values[original.key] = original.value;
    provider.respond = (_) async => throw _offline;
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(provider.calls, 3);
    expect(
      find.text('Could not refresh. Showing the last forecast.'),
      findsOneWidget,
    );
    expect(find.text('· 0m'), findsOneWidget);
    expect(find.text('Cloud cover: 20%'), findsWidgets);
  });

  testWidgets('failed refresh keeps the cached forecast and its original age', (
    tester,
  ) async {
    final originalTime = DateTime.now().toUtc().subtract(
      const Duration(hours: 3),
    );
    final provider = ControlledWeatherProvider(
      (request) async => _mockForecast(request, originalTime, 75),
    );
    final cache = MemoryWeatherCache();
    await _pumpControlledForecast(tester, provider, cache);

    provider.respond = (_) async => throw _offline;
    await tester.tap(find.byTooltip('Refresh forecast'));
    await tester.pumpAndSettle();

    expect(provider.calls, 2);
    expect(cache.values.values.single.fetchedAtUtc, originalTime);
    expect(
      find.text('Could not refresh. Showing the last forecast.'),
      findsOneWidget,
    );
    expect(find.text('Offline cache'), findsOneWidget);
    expect(find.text('· 3h'), findsOneWidget);
    expect(find.text('Cloud cover: 75%'), findsWidgets);
  });

  testWidgets('switching sites during a refresh keeps the new site visible', (
    tester,
  ) async {
    const otherSite = ObservingLocation(
      id: 'other',
      name: 'Other Observatory',
      latitude: 48,
      longitude: 9,
      elevationMeters: 300,
      timeZone: 'Europe/Zurich',
      isDefault: false,
    );
    final site = ValueNotifier(_site);
    addTearDown(site.dispose);
    final provider = ControlledWeatherProvider(
      (request) async => _mockForecast(request, DateTime.now().toUtc(), 75),
    );
    await _pumpControlledForecast(
      tester,
      provider,
      MemoryWeatherCache(),
      forecast: ValueListenableBuilder(
        valueListenable: site,
        builder: (_, selected, _) =>
            SevenNightWeatherWidget(location: selected, instance: _instance),
      ),
    );

    final pending = Completer<WeatherForecast>();
    provider.respond = (request) => request.latitudeDegrees == _site.latitude
        ? pending.future
        : Future.value(_mockForecast(request, DateTime.now().toUtc(), 30));
    await tester.tap(find.byTooltip('Refresh forecast'));
    await tester.pump();
    final oldRequest = provider.requests.last;
    expect(find.text('Updating'), findsOneWidget);

    site.value = otherSite;
    await tester.pumpAndSettle();
    expect(provider.requests.last.latitudeDegrees, otherSite.latitude);
    expect(find.text('Cloud cover: 30%'), findsWidgets);

    pending.complete(_mockForecast(oldRequest, DateTime.now().toUtc(), 20));
    await tester.pumpAndSettle();
    expect(find.text('Cloud cover: 30%'), findsWidgets);
    expect(find.text('Cloud cover: 20%'), findsNothing);
  });

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
            weatherForecastSnapshotProvider.overrideWithBuild((
              ref,
              notifier,
            ) async {
              final request = notifier.request;
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
          weatherForecastSnapshotProvider.overrideWithBuild((
            ref,
            notifier,
          ) async {
            final request = notifier.request;
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
