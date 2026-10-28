import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/geo.dart';
import '../models/match.dart';
import 'app_error.dart';

abstract interface class MatchRepository {
  /// Matchs ouverts à venir dans un rayon autour d'un point, du plus proche au plus lointain.
  Future<List<Match>> searchMatches(MatchSearch search);

  /// Matchs à venir de l'utilisateur (organisés ou rejoints), y compris annulés.
  Future<List<Match>> listMine();

  Future<Match> getMatch(String id);

  Future<List<Participant>> listParticipants(String matchId);

  /// Crée le match et y inscrit l'organisateur ; renvoie l'id du match.
  Future<String> createMatch(MatchInput input);

  Future<void> updateMatch(String id, MatchInput input);

  Future<void> cancelMatch(String id);

  /// Inscrit l'utilisateur ; refusé si le match est complet, annulé, commencé ou déjà rejoint.
  Future<void> joinMatch(String id);

  /// Libère la place de l'utilisateur (impossible pour l'organisateur).
  Future<void> leaveMatch(String id);
}

class SupabaseMatchRepository implements MatchRepository {
  SupabaseMatchRepository(this._client);

  final SupabaseClient _client;

  static const _pageSize = 50;

  @override
  Future<List<Match>> searchMatches(MatchSearch search) => _guard(() async {
    final rows = await _client.rpc('search_matches', params: search.toParams());
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Match.fromJson)
        .toList();
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
            .order('is_organizer', ascending: false)
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

  @override
  Future<void> joinMatch(String id) =>
      _guard(() => _client.rpc('join_match', params: {'p_match_id': id}));

  @override
  Future<void> leaveMatch(String id) =>
      _guard(() => _client.rpc('leave_match', params: {'p_match_id': id}));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}

/// Critères de recherche ; le serveur applique les mêmes bornes.
class MatchSearch {
  const MatchSearch({
    required this.center,
    this.radiusKm = defaultRadiusKm,
    this.availableOnly = false,
    this.skillLevel,
    this.startsBefore,
    this.limit = pageSize,
    this.offset = 0,
  });

  static const defaultRadiusKm = 10;
  static const radiusChoicesKm = [2, 5, 10, 25, 50, 100];
  static const pageSize = 20;

  /// Point de recherche, jamais enregistré par le serveur.
  final GeoPoint center;
  final int radiusKm;
  final bool availableOnly;

  /// `null` : tous les niveaux. Un niveau inclut aussi les matchs « tous niveaux ».
  final SkillLevel? skillLevel;
  final DateTime? startsBefore;
  final int limit;
  final int offset;

  MatchSearch nextPage() => MatchSearch(
    center: center,
    radiusKm: radiusKm,
    availableOnly: availableOnly,
    skillLevel: skillLevel,
    startsBefore: startsBefore,
    limit: limit,
    offset: offset + limit,
  );

  Map<String, dynamic> toParams() => {
    'p_latitude': center.latitude,
    'p_longitude': center.longitude,
    'p_radius_km': radiusKm,
    'p_available_only': availableOnly,
    'p_skill_level': skillLevel?.code,
    'p_starts_before': startsBefore?.toUtc().toIso8601String(),
    'p_limit': limit,
    'p_offset': offset,
  };
}
