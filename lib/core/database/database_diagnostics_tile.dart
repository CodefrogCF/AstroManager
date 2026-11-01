import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_providers.dart';

class DatabaseDiagnosticsTile extends ConsumerStatefulWidget {
  const DatabaseDiagnosticsTile({super.key});

  @override
  ConsumerState<DatabaseDiagnosticsTile> createState() =>
      _DatabaseDiagnosticsTileState();
}

class _DatabaseDiagnosticsTileState
    extends ConsumerState<DatabaseDiagnosticsTile> {
  String _status = 'Not tested';
  bool _running = false;

  Future<void> _runTest() async {
    setState(() {
      _running = true;
      _status = 'Testing SQLite...';
    });

    try {
      final repository = ref.read(appSettingsRepositoryProvider);

      const key = '__diagnostics.sqlite_counter';

      final previous = int.tryParse(await repository.get(key) ?? '0') ?? 0;

      final next = previous + 1;

      await repository.put(key, next.toString());

      final savedValue = await repository.get(key);

      if (savedValue != next.toString()) {
        throw StateError('SQLite read-back verification failed.');
      }

      if (!mounted) return;

      setState(() {
        _status = 'SQLite OK - persistent counter: $next';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _status = 'SQLite ERROR: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storage_outlined),
        title: const Text('Database diagnostics'),
        subtitle: Text(_status),
        trailing: OutlinedButton(
          onPressed: _running ? null : _runTest,
          child: const Text('Test'),
        ),
      ),
    );
  }
}
