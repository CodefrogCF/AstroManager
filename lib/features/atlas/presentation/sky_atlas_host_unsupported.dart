import 'package:flutter/material.dart';

import '../application/sky_atlas_controller.dart';

class AtlasPlatformHost extends StatelessWidget {
  const AtlasPlatformHost({required this.controller, super.key});
  final SkyAtlasController controller;

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Embedded sky atlas is not supported on this platform.'),
  );
}
