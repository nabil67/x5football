import 'dart:typed_data';

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

  /// Remplace la photo de profil (JPEG, PNG ou WebP, 1 Mo au plus, contrôlé par le serveur).
  Future<Profile> updateAvatar(Uint8List bytes, {required String extension});

  Future<Profile> removeAvatar();

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

  static const _bucket = 'avatars';

  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  String get _uid => _client.auth.currentUser!.id;

  Future<Profile> _setAvatarPath(String? path) async {
    final row = await _client
        .from('users')
        .update({'avatar_url': path})
        .eq('id', _uid)
        .select(_columns)
        .single();
    return Profile.fromJson(row);
  }

  /// Supprime les fichiers du dossier personnel, sauf [keep].
  Future<void> _removeAvatarFiles({String? keep}) async {
    final storage = _client.storage.from(_bucket);
    final files = await storage.list(path: _uid);
    final paths = [
      for (final f in files)
        if ('$_uid/${f.name}' != keep) '$_uid/${f.name}',
    ];
    if (paths.isNotEmpty) await storage.remove(paths);
  }

  @override
  Future<Profile> updateAvatar(Uint8List bytes, {required String extension}) =>
      _guard(() async {
        final contentType = _contentTypes[extension];
        if (contentType == null) {
          throw const AppError(
            'AVATAR_INVALID',
            'Format non pris en charge : utilisez une photo JPEG, PNG ou WebP.',
          );
        }
        // Nom unique : évite qu'un ancien cache affiche l'ancienne photo.
        final path =
            '$_uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType),
            );
        final profile = await _setAvatarPath(path);
        // Nettoyage des anciennes photos : un échec ici ne doit pas annuler le changement.
        await _removeAvatarFiles(keep: path).catchError((_) {});
        return profile;
      });

  @override
  Future<Profile> removeAvatar() => _guard(() async {
    final profile = await _setAvatarPath(null);
    await _removeAvatarFiles();
    return profile;
  });

  @override
  Future<void> requestAccountDeletion() => _guard(() async {
    // Photos supprimées d'abord (meilleur effort) : le compte devient ensuite inactif.
    await _removeAvatarFiles().catchError((_) {});
    await _client.rpc('request_account_deletion');
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
