import 'package:astromanager/features/backup/presentation/backup_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('backup settings requires explicit user action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: BackupSettingsSection()),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('backup-export')), findsOneWidget);
    expect(find.byKey(const ValueKey('backup-restore')), findsOneWidget);
    final control = find.byKey(const ValueKey('backup-include-images'));
    expect(control, findsOneWidget);
    await tester.tap(control);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(control).value, isTrue);
  });
}
