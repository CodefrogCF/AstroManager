import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Equipment',
      description: 'Manage cameras, lenses, telescopes and mounts.',
    );
  }
}
