import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'app_error.dart';

abstract interface class ProfileRepository {
  /// Profil de l'utilisateur connecté, ou `null` s'il ne l'a pas encore complété.
  Future<Profile?> fetchMyProfile();

  Future<Profile> completeProfile({
    required String displayName,
    required bool isAdult,
  });

  Future<Profile> updateDisplayName(String displayName);

  /// Bloque le compte immédiatement ; la suppression effective est faite côté serveur.
  Future<void> requestAccountDeletion();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, display_name, avatar_url, account_status';

  @override
  Future<Profile?> fetchMyProfile() => _guard(() async {
    // La RLS ne renvoie que le profil de l'utilisateur connecté.
    final row = await _client.from('users').select(_columns).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  });

  @override
  Future<Profile> completeProfile({
    required String displayName,
    required bool isAdult,
  }) => _guard(() async {
    final row = await _client.rpc(
      'complete_profile',
      params: {'p_display_name': displayName, 'p_is_adult': isAdult},
    );
    return Profile.fromJson(row as Map<String, dynamic>);
  });

  @override
  Future<Profile> updateDisplayName(String displayName) => _guard(() async {
    final row = await _client
        .from('users')
        .update({'display_name': displayName})
        .eq('id', _client.auth.currentUser!.id)
        .select(_columns)
        .single();
    return Profile.fromJson(row);
  });

  @override
  Future<void> requestAccountDeletion() =>
      _guard(() => _client.rpc('request_account_deletion'));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
