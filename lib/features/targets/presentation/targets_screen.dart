import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class TargetsScreen extends StatelessWidget {
  const TargetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Celestial Targets',
      description: 'Find suitable celestial targets.',
    );
  }
}
