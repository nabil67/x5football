import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';
import 'app_error.dart';

abstract interface class MatchRepository {
  /// Matchs à venir ouverts aux inscriptions (hors annulés, terminés, commencés).
  /// La recherche géographique arrive à l'étape 4.
  Future<List<Match>> listUpcoming();

  /// Matchs à venir de l'utilisateur (organisés ou rejoints), y compris annulés.
  Future<List<Match>> listMine();

  Future<Match> getMatch(String id);

  Future<List<Participant>> listParticipants(String matchId);

  /// Crée le match et y inscrit l'organisateur ; renvoie l'id du match.
  Future<String> createMatch(MatchInput input);

  Future<void> updateMatch(String id, MatchInput input);

  Future<void> cancelMatch(String id);
}

class SupabaseMatchRepository implements MatchRepository {
  SupabaseMatchRepository(this._client);

  final SupabaseClient _client;

  static const _pageSize = 50;

  @override
  Future<List<Match>> listUpcoming() => _guard(() async {
    final rows = await _client
        .from('match_details')
        .select()
        .eq('status', 'open')
        .gt('starts_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at')
        .limit(_pageSize);
    return rows.map(Match.fromJson).toList();
  });

  @override
  Future<List<Match>> listMine() => _guard(() async {
    final rows = await _client
        .from('match_details')
        .select()
        .or('is_organizer.eq.true,is_participant.eq.true')
        .gt('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at')
        .limit(_pageSize);
    return rows.map(Match.fromJson).toList();
  });

  @override
  Future<Match> getMatch(String id) => _guard(() async {
    final row = await _client
        .from('match_details')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const AppError('MATCH_NOT_FOUND', 'Ce match est introuvable.');
    }
    return Match.fromJson(row);
  });

  @override
  Future<List<Participant>> listParticipants(String matchId) =>
      _guard(() async {
        final rows = await _client
            .from('match_participants')
            .select()
            .eq('match_id', matchId)
            .order('joined_at');
        return rows.map(Participant.fromJson).toList();
      });

  @override
  Future<String> createMatch(MatchInput input) => _guard(() async {
    final id = await _client.rpc(
      'create_match',
      params: {'p_match': input.toJson()},
    );
    return id as String;
  });

  @override
  Future<void> updateMatch(String id, MatchInput input) => _guard(
    () => _client.rpc(
      'update_match',
      params: {'p_match_id': id, 'p_changes': input.toJson()},
    ),
  );

  @override
  Future<void> cancelMatch(String id) =>
      _guard(() => _client.rpc('cancel_match', params: {'p_match_id': id}));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
