import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/geocoding_repository.dart';
import 'data/location_service.dart';
import 'data/match_repository.dart';
import 'data/profile_repository.dart';
import 'features/auth/auth_gate.dart';

class X5FootballApp extends StatelessWidget {
  const X5FootballApp({
    super.key,
    required this.config,
    required this.auth,
    required this.profiles,
    required this.matches,
    required this.geocoding,
    required this.location,
  });

  final AppConfig config;
  final AuthRepository auth;
  final ProfileRepository profiles;
  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'x5football',
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: config.environment != AppEnvironment.prod,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: AuthGate(
        auth: auth,
        profiles: profiles,
        matches: matches,
        geocoding: geocoding,
        location: location,
      ),
    );
  }
}
