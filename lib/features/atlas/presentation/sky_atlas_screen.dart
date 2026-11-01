import 'package:flutter/material.dart';

import '../../targets/domain/models/celestial_object.dart';
import '../application/sky_atlas_controller.dart';
import '../domain/sky_atlas_models.dart';
import 'sky_atlas_host.dart';

class SkyAtlasScreen extends StatefulWidget {
  const SkyAtlasScreen({super.key, this.target, this.hostBuilder});

  final CelestialObject? target;

  /// Inject a transport in widget tests; no WebView or networking required.
  final Widget Function(SkyAtlasController controller)? hostBuilder;

  @override
  State<SkyAtlasScreen> createState() => _SkyAtlasScreenState();
}

class _SkyAtlasScreenState extends State<SkyAtlasScreen> {
  late final SkyAtlasController _controller;
  int _hostGeneration = 0;

  @override
  void initState() {
    super.initState();
    final object = widget.target;
    final position = object == null
        ? const SkyAtlasPosition(raDegrees: 10.6847, decDegrees: 41.2688)
        : SkyAtlasPosition(
            raDegrees: object.raDegrees,
            decDegrees: object.decDegrees,
          );
    final markers = object == null
        ? <SkyAtlasMarker>[]
        : [
            SkyAtlasMarker(
              id: object.id,
              position: position,
              label: object.displayTitle,
            ),
          ];
    final sizeArcmin = object?.majorAxisArcmin;
    final overlays = sizeArcmin != null && sizeArcmin > 0
        ? [
            SkyAtlasCircleOverlay(
              position: position,
              radiusDegrees: sizeArcmin / 120,
            ),
          ]
        : <SkyAtlasCircleOverlay>[];
    _controller = SkyAtlasController(
      initialPosition: position,
      initialFieldOfViewDegrees: 3,
      initialMarkers: markers,
      initialOverlays: overlays,
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SkyAtlasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target != oldWidget.target && widget.target != null) {
      _selectTarget(widget.target!);
    }
  }

  void _selectTarget(CelestialObject target) {
    final position = SkyAtlasPosition(
      raDegrees: target.raDegrees,
      decDegrees: target.decDegrees,
    );
    _controller.goto(position);
    _controller.setMarkers([
      SkyAtlasMarker(
        id: target.id,
        label: target.displayTitle,
        position: position,
      ),
    ]);
    final sizeArcmin = target.majorAxisArcmin;
    _controller.setOverlays(
      sizeArcmin != null && sizeArcmin > 0
          ? [
              SkyAtlasCircleOverlay(
                position: position,
                radiusDegrees: sizeArcmin / 120,
              ),
            ]
          : [],
    );
  }

  void _retry() {
    setState(() {
      _hostGeneration++;
      _controller.resetLoading();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final target = widget.target;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          target == null ? 'Sky Atlas' : 'Sky Atlas · ${target.displayTitle}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('RA ${controller.position.raDegrees.toStringAsFixed(4)}°'),
                Text(
                  'Dec ${controller.position.decDegrees.toStringAsFixed(4)}°',
                ),
                Text(
                  'FOV ${controller.fieldOfViewDegrees.toStringAsFixed(2)}°',
                ),
                if (target != null)
                  OutlinedButton.icon(
                    key: const ValueKey('atlas-recenter'),
                    onPressed: () => _selectTarget(target),
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Center target'),
                  ),
                for (final fov in [0.5, 1.0, 3.0, 10.0, 30.0])
                  ChoiceChip(
                    key: ValueKey('atlas-fov-$fov'),
                    label: Text('${fov.toStringAsFixed(fov < 1 ? 1 : 0)}°'),
                    selected: controller.fieldOfViewDegrees == fov,
                    onSelected: (_) => controller.setFieldOfView(fov),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        widget.hostBuilder?.call(controller) ??
                        SkyAtlasHost(
                          key: ValueKey(_hostGeneration),
                          controller: controller,
                        ),
                  ),
                  if (controller.status == SkyAtlasStatus.loading)
                    const ColoredBox(
                      color: Color(0xBB111827),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Loading Aladin Lite sky survey...'),
                          ],
                        ),
                      ),
                    ),
                  if (controller.status == SkyAtlasStatus.error)
                    ColoredBox(
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 40),
                            const SizedBox(height: 8),
                            const Text('Sky atlas unavailable'),
                            const SizedBox(height: 8),
                            Text(controller.error ?? 'Unknown atlas error'),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const ValueKey('atlas-retry'),
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Survey imagery: CDS / Aladin Lite (online). ',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
