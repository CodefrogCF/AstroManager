import 'package:flutter/material.dart';

import '../../../../l10n/app_text.dart';

/// Each widget owns its loading lifecycle. One widget failing does not block
/// other dashboard widgets or trigger a full dashboard error state.
enum DashboardLoadStatus { loading, ready, empty, error, unavailable }

final class DashboardLoadState<T> {
  const DashboardLoadState._(this.status, {this.value, this.message});

  final DashboardLoadStatus status;
  final T? value;
  final String? message;

  const DashboardLoadState.loading() : this._(DashboardLoadStatus.loading);
  const DashboardLoadState.data(T value)
    : this._(DashboardLoadStatus.ready, value: value);
  const DashboardLoadState.empty([String? message])
    : this._(DashboardLoadStatus.empty, message: message);
  const DashboardLoadState.error([String? message])
    : this._(DashboardLoadStatus.error, message: message);
  const DashboardLoadState.unavailable([String? message])
    : this._(DashboardLoadStatus.unavailable, message: message);
}

class DashboardWidgetStateView<T> extends StatelessWidget {
  const DashboardWidgetStateView({
    required this.state,
    required this.dataBuilder,
    super.key,
  });

  final DashboardLoadState<T> state;
  final Widget Function(BuildContext, T) dataBuilder;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DashboardLoadStatus.loading:
        return Center(
          child: Semantics(
            label: appTranslate(context, 'Loading dashboard widget'),
            child: const CircularProgressIndicator(),
          ),
        );
      case DashboardLoadStatus.ready:
        final value = state.value;
        if (value == null) {
          return const AppText('No data available.');
        }
        return dataBuilder(context, value);
      case DashboardLoadStatus.empty:
        return _Message(
          icon: Icons.inbox_outlined,
          message: state.message ?? 'No data available.',
        );
      case DashboardLoadStatus.error:
        return _Message(
          icon: Icons.error_outline,
          message: state.message ?? 'Unable to load widget data.',
        );
      case DashboardLoadStatus.unavailable:
        return _Message(
          icon: Icons.hourglass_empty,
          message: state.message ?? 'Data unavailable offline.',
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          AppText(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
