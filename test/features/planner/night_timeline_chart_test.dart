import 'package:astromanager/core/astronomy/solar_events.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/planner/domain/night_observation_block.dart';
import 'package:astromanager/features/planner/domain/night_timeline.dart';
import 'package:astromanager/features/planner/presentation/night_timeline_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const site = ObservingLocation(
  id: 'zrh',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

void main() {
  testWidgets('schedule bar is tappable and overlapping schedule is rendered', (
    tester,
  ) async {
    final timeline = NightTimeline(
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 2),
      ),
    );
    final a = NightObservationBlock(
      id: 'one',
      locationId: site.id,
      nightDate: '2026-11-02',
      timeZoneId: site.timeZone,
      projectId: 'project',
      targetId: 'm31',
      projectName: 'Galaxy',
      targetName: 'M31',
      startUtc: DateTime.utc(2026, 11, 2, 20),
      endUtc: DateTime.utc(2026, 11, 2, 21),
    );
    final b = NightObservationBlock(
      id: 'two',
      locationId: site.id,
      nightDate: '2026-11-02',
      timeZoneId: site.timeZone,
      projectId: 'project',
      targetId: 'm42',
      projectName: 'Nebula',
      targetName: 'M42',
      startUtc: DateTime.utc(2026, 11, 2, 20, 30),
      endUtc: DateTime.utc(2026, 11, 2, 22),
    );
    NightObservationBlock? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NightTimelineChart(
            timeline: timeline,
            location: site,
            visibility: const {},
            blocks: [a, b],
            onEdit: (value) => tapped = value,
            onCreateAt: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('night-timeline-scroll')), findsOneWidget);
    final bar = find.byKey(const ValueKey('night-plan-block-one'));
    await tester.ensureVisible(bar);
    await tester.pump();
    await tester.tap(bar);
    expect(tapped?.id, 'one');
  });

  testWidgets('empty timeline accepts an interactive tap to schedule', (
    tester,
  ) async {
    final timeline = NightTimeline(
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 2),
      ),
    );
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NightTimelineChart(
            timeline: timeline,
            location: site,
            visibility: const {},
            blocks: const [],
            onEdit: (_) {},
            onCreateAt: (utc) => selected = utc,
          ),
        ),
      ),
    );
    find.byKey(const ValueKey('night-timeline-add-track'));
    await tester.ensureVisible(find.text('Tap to schedule a target'));
    await tester.pump();
    await tester.tap(find.text('Tap to schedule a target'));
    expect(selected, isNotNull);
    expect(selected!.isUtc, isTrue);
    expect(timeline.fraction(selected!), inInclusiveRange(0, 1));
  });
}
