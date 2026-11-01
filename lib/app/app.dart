import 'package:flutter/material.dart';

class AstroManagerApp extends StatelessWidget {
  const AstroManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('Architecture ready'))),
    );
  }
}
