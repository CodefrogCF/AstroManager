import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Astrophotography Projects',
      description: 'Organize imaging projects and track progress.',
    );
  }
}
