import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/sky_atlas_controller.dart';

/// Android, iOS and macOS: local HTML asset in system WebView.
/// The upstream webview_flutter plugin does not embed on Windows or Linux.
class AtlasPlatformHost extends StatefulWidget {
  const AtlasPlatformHost({required this.controller, super.key});
  final SkyAtlasController controller;

  @override
  State<AtlasPlatformHost> createState() => _AtlasPlatformHostState();
}

class _AtlasPlatformHostState extends State<AtlasPlatformHost> {
  WebViewController? _webView;
  int _lastSentRevision = -1;
  bool _sentInitial = false;
  Timer? _timeout;

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    if (_supported) {
      _start();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.status == SkyAtlasStatus.loading) {
          widget.controller.reportUnsupported(
            'Embedded sky atlas is not available on Windows/Linux. '
            'Use AstroManager Web in a browser.',
          );
        }
      });
    }
  }

  void _start() {
    final webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AstroManagerBridge',
        onMessageReceived: (message) {
          if (!mounted) return;
          widget.controller.receive(message.message);
          if (widget.controller.status == SkyAtlasStatus.ready ||
              widget.controller.status == SkyAtlasStatus.imageryLoading) {
            _timeout?.cancel();
            _sendCurrentState();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              widget.controller.reportError(error.description);
            }
          },
        ),
      );
    _webView = webView;
    _timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && widget.controller.status == SkyAtlasStatus.loading) {
        widget.controller.reportError(
          'Aladin Lite did not load. Check your internet connection.',
        );
      }
    });
    unawaited(_loadAsset(webView));
  }

  Future<void> _loadAsset(WebViewController webView) async {
    try {
      await webView.loadFlutterAsset('assets/atlas/atlas.html');
    } catch (error) {
      if (mounted) widget.controller.reportError(error.toString());
    }
  }

  Future<void> _runCommand(WebViewController webView, String text) async {
    try {
      await webView.runJavaScript('window.AstroManagerAtlas.receive($text);');
    } catch (error) {
      if (mounted) widget.controller.reportError(error.toString());
    }
  }

  void _onChange() {
    if (widget.controller.status == SkyAtlasStatus.ready ||
        widget.controller.status == SkyAtlasStatus.imageryLoading) {
      _sendCurrentState();
    }
  }

  void _sendCurrentState() {
    if (!_sentInitial || _lastSentRevision != widget.controller.revision) {
      _sentInitial = true;
      _lastSentRevision = widget.controller.revision;
      final webView = _webView;
      if (webView != null) {
        unawaited(
          _runCommand(webView, jsonEncode(widget.controller.stateJson)),
        );
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Embedded Aladin Lite is supported on Web, Android, iOS and macOS. '
            'On Windows/Linux, open the AstroManager web app in a browser.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final webView = _webView;
    if (webView == null) return const SizedBox.shrink();
    return WebViewWidget(controller: webView);
  }
}
