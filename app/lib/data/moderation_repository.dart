import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/moderation.dart';
import 'app_error.dart';

/// Signalements (examinés par une personne, sans sanction automatique) et blocages.
abstract interface class ModerationRepository {
  /// Signale un joueur ([userId]) ou un match ([matchId]), l'un ou l'autre.
  Future<void> report({
    required ReportReason reason,
    String? userId,
    String? matchId,
    String? comment,
  });

  /// La personne bloquée ne peut plus rejoindre vos matchs et vous ne voyez plus les siens.
  Future<void> block(String userId);

  Future<void> unblock(String userId);

  Future<List<BlockedUser>> listBlocked();
}

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> report({
    required ReportReason reason,
    String? userId,
    String? matchId,
    String? comment,
  }) => _guard(
    () => _client.rpc(
      'report',
      params: {
        'p_reason': reason.code,
        'p_user_id': userId,
        'p_match_id': matchId,
        'p_comment': comment,
      },
    ),
  );

  @override
  Future<void> block(String userId) =>
      _guard(() => _client.rpc('block_user', params: {'p_user_id': userId}));

  @override
  Future<void> unblock(String userId) =>
      _guard(() => _client.rpc('unblock_user', params: {'p_user_id': userId}));

  @override
  Future<List<BlockedUser>> listBlocked() => _guard(() async {
    final rows = await _client
        .from('my_blocks')
        .select()
        .order('created_at', ascending: false);
    return rows.map(BlockedUser.fromJson).toList();
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
