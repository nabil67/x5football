import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';

/// Authentification par code à usage unique.
abstract interface class AuthRepository {
  bool get isSignedIn;

  /// Émet à chaque connexion / déconnexion.
  Stream<bool> get signedInChanges;

  Future<void> sendEmailCode(String email);

  Future<void> verifyEmailCode({required String email, required String code});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges =>
      _auth.onAuthStateChange.map((state) => state.session != null).distinct();

  @override
  Future<void> sendEmailCode(String email) async {
    try {
      await _auth.signInWithOtp(email: email, shouldCreateUser: true);
    } catch (e) {
      throw AppError.from(e);
    }
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await _auth.verifyOTP(email: email, token: code, type: OtpType.email);
    } catch (e) {
      throw AppError.from(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
