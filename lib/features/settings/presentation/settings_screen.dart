import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Settings',
      description: 'Configure AstroManager preferences.',
    );
  }
}
