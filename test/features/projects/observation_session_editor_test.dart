import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/providers/database_providers.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/presentation/observation_session_editor_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('session form validates frame counts and saves a UTC log', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    ObservationSession? saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showDialog<ObservationSession>(
                    context: context,
                    builder: (context) =>
                        const ObservationSessionEditorDialog(projectId: 'p1'),
                  );
                },
                child: const Text('Open session'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open session'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('session-exposure')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('session-accepted')), '2');
    await tester.tap(find.byKey(const ValueKey('session-save')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid observation session.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('session-frame-count')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('session-save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.frameCount, 3);
    expect(saved!.acceptedFrames, 2);
    expect(saved!.timeZoneId, 'UTC');
    expect(saved!.startedAtUtc.isUtc, isTrue);
  });
}
