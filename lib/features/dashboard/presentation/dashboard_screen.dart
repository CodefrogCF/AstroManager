import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Welcome to AstroManager',
      description: 'Your astrophotography planning dashboard.',
    );
  }
}
