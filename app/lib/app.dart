import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/geocoding_repository.dart';
import 'data/location_service.dart';
import 'data/match_repository.dart';
import 'data/moderation_repository.dart';
import 'data/notification_repository.dart';
import 'data/profile_repository.dart';
import 'features/auth/auth_gate.dart';
import 'ui/theme.dart';
import 'ui/user_avatar.dart';

class X5FootballApp extends StatelessWidget {
  const X5FootballApp({
    super.key,
    required this.config,
    required this.auth,
    required this.profiles,
    required this.matches,
    required this.geocoding,
    required this.location,
    required this.notifications,
    required this.moderation,
    this.avatarResolver,
  });

  final AppConfig config;
  final AuthRepository auth;
  final ProfileRepository profiles;
  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;
  final NotificationRepository notifications;
  final ModerationRepository moderation;

  /// Accès aux photos de profil ; absent dans les tests (initiales affichées).
  final AvatarResolver? avatarResolver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'x5football',
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: config.environment != AppEnvironment.prod,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) => avatarResolver == null
          ? child!
          : AvatarImages(resolve: avatarResolver!, child: child!),
      home: AuthGate(
        auth: auth,
        profiles: profiles,
        matches: matches,
        geocoding: geocoding,
        location: location,
        notifications: notifications,
        moderation: moderation,
      ),
    );
  }
}
