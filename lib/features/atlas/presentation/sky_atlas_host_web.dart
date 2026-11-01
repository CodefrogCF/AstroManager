import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';

import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '../application/sky_atlas_controller.dart';

int _nextViewId = 0;

/// Web: a same-origin Flutter asset iframe and versioned postMessage packets.
class AtlasPlatformHost extends StatefulWidget {
  const AtlasPlatformHost({required this.controller, super.key});
  final SkyAtlasController controller;

  @override
  State<AtlasPlatformHost> createState() => _AtlasPlatformHostState();
}

class _AtlasPlatformHostState extends State<AtlasPlatformHost> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final JSFunction _handler;
  int _lastSentRevision = -1;
  bool _sentInitial = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _viewType = 'astromanager-aladin-${_nextViewId++}';
    _iframe = web.HTMLIFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..src = Uri.parse(web.document.baseURI)
          .resolve('assets/assets/atlas/atlas.html')
          .toString();

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) => _iframe,
    );

    _handler = ((web.Event event) {
      final message = event as web.MessageEvent;
      if (message.origin != web.window.location.origin ||
          message.source != _iframe.contentWindow) {
        return;
      }
      final data = message.data.dartify();
      if (data is! String) return;
      widget.controller.receive(data);
      if (widget.controller.status == SkyAtlasStatus.ready) {
        _timeout?.cancel();
        _sendCurrentState();
      }
    }).toJS;
    web.window.addEventListener('message', _handler);
    widget.controller.addListener(_onChange);
    _timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && widget.controller.status == SkyAtlasStatus.loading) {
        widget.controller.reportError(
          'Aladin Lite did not load. Check the internet connection.',
        );
      }
    });
  }

  void _onChange() {
    if (widget.controller.status == SkyAtlasStatus.ready) _sendCurrentState();
  }

  void _sendCurrentState() {
    if (!_sentInitial || _lastSentRevision != widget.controller.revision) {
      _sentInitial = true;
      _lastSentRevision = widget.controller.revision;
      _iframe.contentWindow?.postMessage(
        widget.controller.stateJson.toJS,
        web.window.location.origin.toJS,
      );
    }
  }

  @override
  void didUpdateWidget(covariant AtlasPlatformHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _lastSentRevision = -1;
      _sentInitial = false;
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    widget.controller.removeListener(_onChange);
    web.window.removeEventListener('message', _handler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
