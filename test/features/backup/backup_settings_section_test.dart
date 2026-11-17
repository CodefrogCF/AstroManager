import 'dart:typed_data';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/features/backup/data/backup_service.dart';
import 'package:astromanager/features/backup/presentation/backup_settings_section.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _PickedBackup extends PlatformFile {
  _PickedBackup(this.bytes);

  final Uint8List bytes;

  @override
  String get name => 'AstroManager-test.ambackup';

  @override
  Uri get uri => Uri.dataFromBytes(bytes);

  @override
  Never get xFile => throw UnsupportedError('Unused by backup restore');

  @override
  int lengthSync() => bytes.length;

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

final class _PickerWithoutCustomMimeType extends FilePickerPlatform {
  _PickerWithoutCustomMimeType(this.file);

  final PlatformFile file;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => type == FileType.any && allowedExtensions == null ? file : null;
}

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

  testWidgets('restores a current .ambackup without a registered MIME type', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() async {
      final source = AppDatabase(NativeDatabase.memory());
      try {
        await source
            .into(source.observingLocations)
            .insert(
              ObservingLocationsCompanion.insert(
                id: 'test-site',
                name: 'Test Observatory',
                latitude: 52.52,
                longitude: 13.405,
                elevationMeters: 30,
                timeZone: 'Europe/Berlin',
              ),
            );
        return await AstroBackupService(source).export(includeImages: false);
      } finally {
        await source.close();
      }
    });
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(destination.close);
    await tester.runAsync(() => destination.customSelect('SELECT 1').get());
    final originalPicker = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    FilePickerPlatform.instance = _PickerWithoutCustomMimeType(
      _PickedBackup(bytes!),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          astroBackupServiceProvider.overrideWithValue(
            AstroBackupService(destination),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: BackupSettingsSection()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('backup-restore')));
    await tester.pump();
    // The import progress indicator keeps animating behind the preview.
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Restore AstroManager backup?'), findsOneWidget);
    await tester.tap(find.text('Merge (no overwrites)'));
    await tester.pumpAndSettle();

    final sites = await tester.runAsync(
      () => destination.select(destination.observingLocations).get(),
    );
    expect(sites!.single.name, 'Test Observatory');
  });
}
