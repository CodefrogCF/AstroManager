import 'dart:convert';

import 'package:astromanager/features/dashboard/presentation/widgets/observing_site_conditions_widget.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/locations/presentation/locations_screen.dart';
import 'package:astromanager/features/terrain/application/terrain_providers.dart';
import 'package:astromanager/features/terrain/data/open_topo_data_provider.dart';
import 'package:astromanager/features/terrain/data/terrain_profile_repository.dart';
import 'package:astromanager/features/terrain/domain/terrain_horizon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _default = ObservingLocation(
  id: 'bern',
  name: 'Bern',
  latitude: 46.948,
  longitude: 7.4474,
  elevationMeters: 540,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

const _selected = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: false,
);

class _Store implements TerrainProfileStore {
  final _values = <String, String>{};

  @override
  Future<Set<String>> getKeys() async => _values.keys.toSet();

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

void main() {
  testWidgets(
    'a selected EU-DEM site can load terrain and display it offline',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = _Store();
      final requests = <Uri>[];
      var hasCoverage = false;
      var offline = false;
      final client = MockClient((request) async {
        requests.add(request.url);
        if (offline) return http.Response('', 503);
        final points = request.url.queryParameters['locations']!.split('|');
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              for (final _ in points) {'elevation': hasCoverage ? 550 : null},
            ],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final provider = OpenTopoDataElevationProvider(
        client: client,
        betweenRequests: Duration.zero,
      );
      Future<TerrainProfileRepository> open() async {
        final repository = TerrainProfileRepository(
          provider: provider,
          store: store,
        );
        addTearDown(repository.dispose);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              observingLocationsProvider.overrideWithBuild(
                (ref, notifier) => const [_default, _selected],
              ),
              terrainProfileRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    Expanded(child: LocationsScreen()),
                    Expanded(
                      child: ObservingSiteConditionsWidget(location: _selected),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return repository;
      }

      final repository = await open();
      expect(requests, isEmpty);
      expect(
        find.text('No terrain profile saved for this site.'),
        findsWidgets,
      );
      final fetch = find.byKey(const ValueKey('location-terrain-fetch-zurich'));
      Future<void> fetchTerrain() async {
        await tester.ensureVisible(fetch);
        await tester.tap(fetch);
        await tester.pumpAndSettle();
      }

      await fetchTerrain();
      expect(
        find.text('No usable elevation data for this site and search radius.'),
        findsOneWidget,
      );
      expect(await repository.cachedAnyForSite(_selected), isNull);

      requests.clear();
      hasCoverage = true;
      await fetchTerrain();
      expect(requests, isNotEmpty);
      expect(requests.every((uri) => uri.path == '/v1/eudem25m'), isTrue);
      final firstPoint = requests.first.queryParameters['locations']!
          .split('|')
          .first
          .split(',');
      expect(double.parse(firstPoint[0]), closeTo(_selected.latitude, 0.01));
      expect(double.parse(firstPoint[1]), _selected.longitude);
      expect(await repository.cachedAnyForSite(_default), isNull);
      final profile = await repository.cached(
        _selected,
        const TerrainHorizonOptions(),
      );
      expect(profile?.observerElevationMeters, _selected.elevationMeters);
      expect(
        find.byKey(const ValueKey('terrain-horizon-plot')),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const ValueKey('dashboard-site-terrain-summary')),
        findsOneWidget,
      );

      offline = true;
      await fetchTerrain();
      expect(
        find.text(
          'Could not load elevation data. Check your connection or try again later.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('terrain-horizon-plot')),
        findsNWidgets(2),
      );
      final requestCount = requests.length;
      await open();
      expect(requests, hasLength(requestCount));
      expect(
        find.byKey(const ValueKey('terrain-horizon-plot')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
