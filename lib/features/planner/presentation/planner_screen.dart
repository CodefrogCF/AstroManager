import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Night Planner',
      description: 'Plan your upcoming astrophotography sessions.',
    );
  }
}
