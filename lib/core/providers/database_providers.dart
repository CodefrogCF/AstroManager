import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/repositories/app_settings_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();

  ref.onDispose(() {
    unawaited(database.close());
  });

  return database;
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return AppSettingsRepository(database);
});
