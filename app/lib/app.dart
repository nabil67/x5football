import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/profile_repository.dart';
import 'features/auth/auth_gate.dart';

class X5FootballApp extends StatelessWidget {
  const X5FootballApp({
    super.key,
    required this.config,
    required this.auth,
    required this.profiles,
  });

  final AppConfig config;
  final AuthRepository auth;
  final ProfileRepository profiles;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'x5football',
      debugShowCheckedModeBanner: config.environment != AppEnvironment.prod,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: AuthGate(auth: auth, profiles: profiles),
    );
  }
}
