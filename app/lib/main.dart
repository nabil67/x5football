import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/geocoding_repository.dart';
import 'data/location_service.dart';
import 'data/match_repository.dart';
import 'data/notification_repository.dart';
import 'data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR');
  final config = AppConfig.fromEnvironment();
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );
  final client = Supabase.instance.client;

  runApp(
    X5FootballApp(
      config: config,
      auth: SupabaseAuthRepository(client.auth),
      profiles: SupabaseProfileRepository(client),
      matches: SupabaseMatchRepository(client),
      geocoding: SupabaseGeocodingRepository(client),
      location: GeolocatorLocationService(),
      notifications: SupabaseNotificationRepository(client),
      // Bucket privé : chaque photo est demandée avec le jeton de la session en cours.
      avatarResolver: (path) => NetworkImage(
        '${config.supabaseUrl}/storage/v1/object/authenticated/avatars/$path',
        headers: {
          'apikey': config.supabasePublishableKey,
          'Authorization': 'Bearer ${client.auth.currentSession?.accessToken}',
        },
      ),
    ),
  );
}
