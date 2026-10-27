import 'dart:convert';

/// Environnements d'exécution supportés.
enum AppEnvironment { dev, test, prod }

/// Configuration injectée à la compilation via `--dart-define-from-file`.
///
/// Seules des valeurs publiques (URL et clé publishable) sont autorisées
/// ici : tout ce qui est compilé dans l'application peut être extrait.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Lit la configuration fournie à la compilation.
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    environment: const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
  );

  /// Valide des valeurs brutes et lève [AppConfigException] si elles sont
  /// absentes, mal formées ou dangereuses.
  factory AppConfig.parse({
    required String environment,
    required String supabaseUrl,
    required String supabasePublishableKey,
  }) {
    final env = AppEnvironment.values.where((e) => e.name == environment);
    if (env.isEmpty) {
      throw AppConfigException('APP_ENV invalide : "$environment".');
    }

    final uri = Uri.tryParse(supabaseUrl);
    if (supabaseUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      throw const AppConfigException(
        'SUPABASE_URL manquante ou invalide. Lancez l\'application avec '
        '--dart-define-from-file=env/<environnement>.json.',
      );
    }
    if (env.first == AppEnvironment.prod && uri.scheme != 'https') {
      throw const AppConfigException(
        'SUPABASE_URL doit utiliser https en production.',
      );
    }

    if (supabasePublishableKey.isEmpty) {
      throw const AppConfigException('SUPABASE_PUBLISHABLE_KEY manquante.');
    }
    if (_isSecretKey(supabasePublishableKey)) {
      throw const AppConfigException(
        'Une clé secrète/service_role a été fournie au client. '
        'Utilisez uniquement la clé publishable.',
      );
    }

    return AppConfig(
      environment: env.first,
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: supabasePublishableKey,
    );
  }

  static bool _isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    // Anciennes clés JWT : refuser le rôle service_role.
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}
