import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    ),
  );
}
