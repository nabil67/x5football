import 'package:flutter/material.dart';

import 'config/app_config.dart';

class X5FootballApp extends StatelessWidget {
  const X5FootballApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'x5football',
      debugShowCheckedModeBanner: config.environment != AppEnvironment.prod,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const _PlaceholderHome(),
    );
  }
}

/// Écran temporaire, remplacé à l'étape 2 par le parcours d'authentification.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('x5football')));
  }
}
