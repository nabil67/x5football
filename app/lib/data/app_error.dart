import 'package:supabase_flutter/supabase_flutter.dart';

/// Erreur exploitable par l'interface : [code] est stable (ex. `AGE_NOT_CONFIRMED`),
/// [message] est affichable tel quel.
class AppError implements Exception {
  const AppError(this.code, this.message);

  final String code;
  final String message;

  static const genericMessage =
      'Une erreur est survenue. Réessayez dans un instant.';

  /// Convertit une erreur technique en [AppError].
  ///
  /// Les RPC du projet lèvent des erreurs `PTxxx` dont `message` est le code
  /// métier et `hint` le texte destiné à l'utilisateur.
  factory AppError.from(Object error) {
    if (error is AppError) return error;
    if (error is PostgrestException) {
      final isBusinessError = error.code?.startsWith('PT') ?? false;
      if (isBusinessError && error.hint != null) {
        return AppError(error.message, error.hint!);
      }
      return const AppError('SERVER_ERROR', genericMessage);
    }
    // Edge Functions du projet : corps `{ "code": "...", "message": "..." }` en français.
    // Les refus de la passerelle (jeton absent ou expiré) ont un texte anglais : non affiché.
    if (error is FunctionException) {
      if (error.status == 401) {
        return const AppError(
          'AUTH_REQUIRED',
          'Votre session a expiré. Reconnectez-vous.',
        );
      }
      final details = error.details;
      if (details is Map &&
          details['code'] is String &&
          details['message'] is String) {
        return AppError(
          details['code'] as String,
          details['message'] as String,
        );
      }
      return const AppError('SERVER_ERROR', genericMessage);
    }
    if (error is AuthException) {
      return switch (error.code) {
        'otp_expired' => const AppError(
          'OTP_INVALID',
          'Code invalide ou expiré.',
        ),
        'over_email_send_rate_limit' ||
        'over_request_rate_limit' => const AppError(
          'RATE_LIMITED',
          'Trop de tentatives. Patientez avant de réessayer.',
        ),
        'email_address_invalid' => const AppError(
          'EMAIL_INVALID',
          'Adresse e-mail invalide.',
        ),
        _ => const AppError('AUTH_ERROR', genericMessage),
      };
    }
    return const AppError('UNKNOWN', genericMessage);
  }

  @override
  String toString() => 'AppError($code)';
}
