// This opt-in benchmark reports its measurements through Flutter's test runner.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/features/discovery/application/discovery_evaluator.dart';
import 'package:astromanager/features/targets/data/catalog_asset_source.dart';
import 'package:astromanager/features/targets/data/drift_celestial_catalog_repository.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/features/intelligence/fixtures/recommendation_scenarios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('measure offline planning with the bundled catalog', () async {
    final directory = await Directory.systemTemp.createTemp('astro-benchmark-');
    final file = File('${directory.path}/catalog.sqlite');
    const source = BundledOpenNgcCatalogSource();
    final startRss = ProcessInfo.currentRss;

    try {
      final coldDatabase = AppDatabase(NativeDatabase.createInBackground(file));
      late final int entries;
      try {
        final repository = DriftCelestialCatalogRepository(coldDatabase);
        final cold = Stopwatch()..start();
        final bundle = await source.load();
        final assetMillis = cold.elapsedMilliseconds;
        await repository.seedIfNeeded(bundle);
        entries = await repository.count();
        expect(entries, bundle.objects.length);
        print(
          'Cold catalog ${cold.elapsedMilliseconds} ms '
          '(asset read and decode $assetMillis ms, ${bundle.version}, '
          '$entries entries)',
        );
      } finally {
        await coldDatabase.close();
      }
      print('SQLite file ${await file.length()} bytes');
      rootBundle.evict(source.assetPath);
      final database = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        final repository = DriftCelestialCatalogRepository(database);
        final reopen = Stopwatch()..start();
        await repository.seedIfNeeded(await source.load());
        expect(await repository.count(), entries);
        print(
          'Reopen and verify seeded catalog ${reopen.elapsedMilliseconds} ms',
        );

        final search = await repository.search(query: 'NGC0224');
        expect(search, isNotEmpty);
        final target = search.first;
        final position = EquatorialPosition(
          raDegrees: target.raDegrees,
          decDegrees: target.decDegrees,
        );
        final category = CelestialCategory.galaxy;
        final shortlist = await repository.discoveryCandidates(limit: 24);
        expect(shortlist, hasLength(24));

        await _measure('Catalog browse (80 rows)', 80, repository.search);
        await _measure('Substring lookup (NGC0224)', 80, () {
          return repository.search(query: 'NGC0224');
        });
        await _measure('Category browse (80 galaxies)', 80, () {
          return repository.search(category: category);
        });
        await _measure('Catalog ID', 80, () => repository.findById(target.id));
        await _measure('Atlas position', 80, () {
          return repository.findAt(position, toleranceDegrees: 0.25);
        });
        await _measure('Discovery shortlist (24 rows)', 80, () {
          return repository.discoveryCandidates(limit: 24);
        });
        final forecast = RecommendationScenarios.forecast(
          hoursUtc: [
            for (var hour = 0; hour < 24; hour++)
              DateTime.utc(2026, 11, 1, 12 + hour),
          ],
        );
        Future<void> evaluate() async {
          final results = await const DefaultDiscoveryEvaluator().evaluate(
            targets: shortlist,
            location: RecommendationScenarios.location,
            localDate: DateTime(2026, 11, 1),
            evaluatedAtUtc: RecommendationScenarios.evaluatedAtUtc,
            minimumDurationMinutes: 60,
            minimumAltitudeDegrees: 25,
            weather: forecast,
            optics: RecommendationScenarios.optics,
            isCurrent: () => true,
          );
          expect(results, isNotEmpty);
        }

        await evaluate();
        _printRss('Planning warm', startRss);
        await _measure('Rank 24 candidates for one night', 50, evaluate);
        _printRss('After 50 evaluations', startRss);
      } finally {
        await database.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Future<void> _measure(
  String label,
  int samples,
  Future<Object?> Function() run,
) async {
  for (var warmup = 0; warmup < 5; warmup++) {
    await run();
  }
  final times = <int>[];
  final timer = Stopwatch()..start();
  for (var sample = 0; sample < samples; sample++) {
    timer.reset();
    await run();
    times.add(timer.elapsedMicroseconds);
  }
  times.sort();
  String percentile(double probability) =>
      (times[(samples * probability).ceil() - 1] / 1000).toStringAsFixed(2);
  print(
    '$label ($samples samples) '
    'p50 ${percentile(0.5)} ms, p95 ${percentile(0.95)} ms, '
    'max ${percentile(1)} ms',
  );
}

void _printRss(String stage, int startRss) {
  String mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
  print(
    '$stage RSS ${mib(ProcessInfo.currentRss)} MiB '
    '(baseline ${mib(startRss)} MiB, peak ${mib(ProcessInfo.maxRss)} MiB)',
  );
}
