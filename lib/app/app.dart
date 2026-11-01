import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';

class AstroManagerApp extends StatefulWidget {
  const AstroManagerApp({super.key, this.initialLocation});

  final String? initialLocation;

  @override
  State<AstroManagerApp> createState() => _AstroManagerAppState();
}

class _AstroManagerAppState extends State<AstroManagerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = createAppRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AstroManager',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
    );
  }
}
