import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:x5football/config/app_config.dart';

String _jwtWithRole(String role) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'role': role})}.signature';
}

void main() {
  AppConfig parse({
    String environment = 'dev',
    String url = 'http://10.0.2.2:54321',
    String key = 'sb_publishable_abc',
  }) => AppConfig.parse(
    environment: environment,
    supabaseUrl: url,
    supabasePublishableKey: key,
  );

  test('accepte une configuration de développement valide', () {
    final config = parse();
    expect(config.environment, AppEnvironment.dev);
    expect(config.supabaseUrl, 'http://10.0.2.2:54321');
  });

  test('accepte une ancienne clé JWT anon', () {
    expect(() => parse(key: _jwtWithRole('anon')), returnsNormally);
  });

  test('refuse un environnement inconnu', () {
    expect(
      () => parse(environment: 'staging'),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('refuse une URL absente ou invalide', () {
    expect(() => parse(url: ''), throwsA(isA<AppConfigException>()));
    expect(() => parse(url: 'pas une url'), throwsA(isA<AppConfigException>()));
  });

  test('exige https en production', () {
    expect(
      () => parse(environment: 'prod', url: 'http://exemple.supabase.co'),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => parse(environment: 'prod', url: 'https://exemple.supabase.co'),
      returnsNormally,
    );
  });

  test('refuse une clé absente', () {
    expect(() => parse(key: ''), throwsA(isA<AppConfigException>()));
  });

  test('refuse une clé secrète ou service_role côté client', () {
    expect(
      () => parse(key: 'sb_secret_xyz'),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => parse(key: _jwtWithRole('service_role')),
      throwsA(isA<AppConfigException>()),
    );
  });
}
