import 'package:flutter/material.dart';

import '../application/sky_atlas_controller.dart';
import 'sky_atlas_host_unsupported.dart'
    if (dart.library.js_interop) 'sky_atlas_host_web.dart'
    if (dart.library.io) 'sky_atlas_host_native.dart'
    as platform;

/// Isolates native/web embedding and messaging behind one widget.
class SkyAtlasHost extends StatelessWidget {
  const SkyAtlasHost({required this.controller, super.key});

  final SkyAtlasController controller;

  @override
  Widget build(BuildContext context) =>
      platform.AtlasPlatformHost(controller: controller);
}
