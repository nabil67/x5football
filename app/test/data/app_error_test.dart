import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:x5football/data/app_error.dart';

void main() {
  test('une erreur métier PTxxx expose son code et son message', () {
    final error = AppError.from(
      const PostgrestException(
        message: 'AGE_NOT_CONFIRMED',
        code: 'PT422',
        hint: 'Réservé aux adultes.',
      ),
    );
    expect(error.code, 'AGE_NOT_CONFIRMED');
    expect(error.message, 'Réservé aux adultes.');
  });

  test('une erreur technique PostgREST reste générique', () {
    final error = AppError.from(
      const PostgrestException(
        message: 'permission denied for table users',
        code: '42501',
        hint: 'GRANT …',
      ),
    );
    expect(error.code, 'SERVER_ERROR');
    expect(error.message, AppError.genericMessage);
  });

  test('code OTP expiré', () {
    final error = AppError.from(
      const AuthException('Token has expired', code: 'otp_expired'),
    );
    expect(error.code, 'OTP_INVALID');
  });

  test('erreur métier d\'une Edge Function', () {
    final error = AppError.from(
      const FunctionException(
        status: 429,
        details: {
          'code': 'GEOCODE_RATE_LIMITED',
          'message': 'Trop de recherches d\'adresse.',
        },
      ),
    );
    expect(error.code, 'GEOCODE_RATE_LIMITED');
    expect(error.message, 'Trop de recherches d\'adresse.');
  });

  test('refus de la passerelle (texte anglais) non affiché', () {
    final error = AppError.from(
      const FunctionException(
        status: 401,
        details: {'code': 'UNAUTHORIZED', 'message': 'Invalid JWT'},
      ),
    );
    expect(error.code, 'AUTH_REQUIRED');
    expect(error.message, contains('Reconnectez-vous'));
  });

  test('réponse inattendue d\'une Edge Function', () {
    final error = AppError.from(
      const FunctionException(status: 500, details: 'Internal error'),
    );
    expect(error.message, AppError.genericMessage);
  });

  test('erreur inconnue', () {
    expect(AppError.from(StateError('boom')).message, AppError.genericMessage);
  });
}
