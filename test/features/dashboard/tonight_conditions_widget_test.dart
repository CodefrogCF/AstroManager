import 'package:astromanager/features/dashboard/application/tonight_conditions_provider.dart';
import 'package:astromanager/features/dashboard/domain/tonight_conditions.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/tonight_conditions_widget.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = ObservingLocation(
  id: 'ch',
  name: 'Swiss Observatory',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

void main() {
  testWidgets(
    'missing location shows empty state without evaluating ephemerides',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: TonightConditionsWidget(location: null)),
          ),
        ),
      );
      expect(find.text('No observing location selected.'), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard-tonight')), findsNothing);
    },
  );

  testWidgets('conditions show darkness, sun, moon and planner action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 650,
              height: 620,
              child: TonightConditionsWidget(
                location: _site,
                referenceUtc: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-tonight')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-tonight-darkness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-tonight-remaining')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-tonight-sunset')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-tonight-dusk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-tonight-moon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-tonight-planner')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow tile at 200% text scale remains scrollable without overflows',
    (tester) async {
      final height = ValueNotifier<double>(420);
      addTearDown(height.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (context, h, child) =>
                        SizedBox(width: 220, height: h, child: child),
                    child: const TonightConditionsWidget(
                      location: _site,
                      referenceUtc: null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dashboard-tonight')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-tonight-dusk')),
        findsNothing,
      );
      final details = find.byKey(const ValueKey('dashboard-tonight-details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dashboard-tonight-dusk')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      height.value = 180;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dashboard-tonight')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reused location and date do not re-evaluate on rebuild', (
    tester,
  ) async {
    var evaluations = 0;
    final clock = DateTime.utc(2026, 11, 4, 1);
    final host = ValueNotifier<int>(0);
    addTearDown(host.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tonightConditionsProvider.overrideWith((ref, query) async {
            evaluations++;
            return TonightConditionsCalculator.calculate(
              location: query.location,
              localDate: query.localDate,
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: host,
              builder: (_, value, _) => SizedBox(
                width: 500,
                height: 520,
                child: TonightConditionsWidget(
                  location: _site,
                  referenceUtc: clock,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(evaluations, 1);
    host.value++;
    await tester.pumpAndSettle();
    expect(evaluations, 1);
  });
}
