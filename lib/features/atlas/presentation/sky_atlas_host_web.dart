import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../application/sky_atlas_controller.dart';

/// Web: an isolated Flutter asset iframe and versioned postMessage packets.
class AtlasPlatformHost extends StatefulWidget {
  const AtlasPlatformHost({required this.controller, super.key});
  final SkyAtlasController controller;

  @override
  State<AtlasPlatformHost> createState() => _AtlasPlatformHostState();
}

class _AtlasPlatformHostState extends State<AtlasPlatformHost> {
  web.HTMLIFrameElement? _iframe;
  late final JSFunction _handler;
  int _lastSentRevision = -1;
  bool _sentInitial = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _handler = ((web.Event event) {
      final message = event as web.MessageEvent;
      final frame = _iframe?.contentWindow;
      if (frame == null ||
          message.origin != 'null' ||
          !frame.strictEquals(message.source).toDart) {
        return;
      }
      final data = message.data.dartify();
      if (data is! String) return;
      widget.controller.receive(data);
      if (widget.controller.status == SkyAtlasStatus.ready ||
          widget.controller.status == SkyAtlasStatus.imageryLoading) {
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

  void _configureFrame(Object element) {
    _iframe = (element as web.HTMLIFrameElement)
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.pointerEvents = widget.controller.pointerInputEnabled
          ? ''
          : 'none'
      // Remote Aladin code must not inherit access to the app's web storage.
      ..sandbox.add('allow-scripts')
      ..sandbox.add('allow-popups')
      ..sandbox.add('allow-popups-to-escape-sandbox')
      ..referrerPolicy = 'no-referrer'
      ..src = Uri.parse(web.document.baseURI)
          .resolve('assets/assets/atlas/atlas.html')
          .toString();
  }

  void _onChange() {
    // An iframe otherwise captures pointer events even below a Flutter dialog.
    _iframe?.style.pointerEvents = widget.controller.pointerInputEnabled
        ? ''
        : 'none';
    if (widget.controller.status == SkyAtlasStatus.ready ||
        widget.controller.status == SkyAtlasStatus.imageryLoading) {
      _sendCurrentState();
    }
  }

  void _sendCurrentState() {
    final frame = _iframe?.contentWindow;
    if (frame == null) return;
    if (!_sentInitial || _lastSentRevision != widget.controller.revision) {
      _sentInitial = true;
      _lastSentRevision = widget.controller.revision;
      // The sandbox has an opaque origin. Send only to this frame's window.
      frame.postMessage(widget.controller.stateJson.toJS, '*'.toJS);
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
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: _configureFrame,
  );
}
