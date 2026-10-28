enum MatchFormat {
  fiveASide('5v5', '5 contre 5', 10),
  sevenASide('7v7', '7 contre 7', 14),
  elevenASide('11v11', '11 contre 11', 22);

  const MatchFormat(this.code, this.label, this.suggestedCapacity);

  final String code;
  final String label;

  /// Valeur proposée dans le formulaire, jamais imposée.
  final int suggestedCapacity;

  static MatchFormat fromCode(String code) =>
      values.firstWhere((f) => f.code == code);
}

enum SkillLevel {
  all('all', 'Tous niveaux'),
  beginner('beginner', 'Débutant'),
  intermediate('intermediate', 'Intermédiaire'),
  advanced('advanced', 'Confirmé');

  const SkillLevel(this.code, this.label);

  final String code;
  final String label;

  static SkillLevel fromCode(String code) =>
      values.firstWhere((l) => l.code == code);
}

enum LocationMode {
  fixed('fixed'),
  toDefine('to_define');

  const LocationMode(this.code);

  final String code;

  static LocationMode fromCode(String code) =>
      values.firstWhere((m) => m.code == code);
}

/// État affiché, calculé par le serveur (vue `match_details`).
enum MatchDisplayStatus {
  open('open', 'Ouvert'),
  full('full', 'Complet'),
  inProgress('in_progress', 'En cours'),
  completed('completed', 'Terminé'),
  cancelled('cancelled', 'Annulé');

  const MatchDisplayStatus(this.code, this.label);

  final String code;
  final String label;

  static MatchDisplayStatus fromCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

class Match {
  const Match({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    required this.capacity,
    required this.participantCount,
    required this.spotsLeft,
    required this.format,
    required this.skillLevel,
    required this.locationMode,
    required this.displayStatus,
    required this.isOrganizer,
    required this.isParticipant,
    this.description,
    this.locationName,
    this.latitude,
    this.longitude,
    this.estimatedTotalCost,
    this.estimatedCostPerPlayer,
    this.currency = 'EUR',
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'] as String,
    organizerId: json['organizer_id'] as String,
    organizerName: json['organizer_name'] as String?,
    title: json['title'] as String,
    description: json['description'] as String?,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    durationMinutes: json['duration_minutes'] as int,
    capacity: json['capacity'] as int,
    participantCount: json['participant_count'] as int,
    spotsLeft: json['spots_left'] as int,
    format: MatchFormat.fromCode(json['format'] as String),
    skillLevel: SkillLevel.fromCode(json['skill_level'] as String),
    locationMode: LocationMode.fromCode(json['location_mode'] as String),
    locationName: json['location_name'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    estimatedTotalCost: (json['estimated_total_cost'] as num?)?.toDouble(),
    estimatedCostPerPlayer: (json['estimated_cost_per_player'] as num?)
        ?.toDouble(),
    currency: json['currency'] as String? ?? 'EUR',
    displayStatus: MatchDisplayStatus.fromCode(
      json['display_status'] as String,
    ),
    isOrganizer: json['is_organizer'] as bool,
    isParticipant: json['is_participant'] as bool,
  );

  final String id;
  final String organizerId;

  /// `null` si le compte de l'organisateur n'est plus actif.
  final String? organizerName;
  final String title;
  final String? description;
  final DateTime startsAt;
  final int durationMinutes;
  final int capacity;
  final int participantCount;
  final int spotsLeft;
  final MatchFormat format;
  final SkillLevel skillLevel;
  final LocationMode locationMode;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final double? estimatedTotalCost;
  final double? estimatedCostPerPlayer;
  final String currency;
  final MatchDisplayStatus displayStatus;
  final bool isOrganizer;
  final bool isParticipant;

  bool get isLocationConfirmed => locationMode == LocationMode.fixed;

  /// L'organisateur ne peut modifier ou annuler qu'un match ouvert ou complet, pas encore commencé.
  bool get isEditable =>
      displayStatus == MatchDisplayStatus.open ||
      displayStatus == MatchDisplayStatus.full;
}

/// Saisie du formulaire de création / modification, envoyée telle quelle aux RPC.
class MatchInput {
  const MatchInput({
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    required this.capacity,
    required this.format,
    required this.skillLevel,
    required this.locationMode,
    this.description,
    this.locationName,
    this.latitude,
    this.longitude,
    this.estimatedTotalCost,
    this.estimatedCostPerPlayer,
  });

  final String title;
  final String? description;
  final DateTime startsAt;
  final int durationMinutes;
  final int capacity;
  final MatchFormat format;
  final SkillLevel skillLevel;
  final LocationMode locationMode;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final double? estimatedTotalCost;
  final double? estimatedCostPerPlayer;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'duration_minutes': durationMinutes,
    'capacity': capacity,
    'format': format.code,
    'skill_level': skillLevel.code,
    'location_mode': locationMode.code,
    'location_name': locationName,
    // Jamais de position pour un lieu à définir.
    'latitude': locationMode == LocationMode.fixed ? latitude : null,
    'longitude': locationMode == LocationMode.fixed ? longitude : null,
    'estimated_total_cost': estimatedTotalCost,
    'estimated_cost_per_player': estimatedCostPerPlayer,
  };
}

class Participant {
  const Participant({
    required this.userId,
    required this.displayName,
    required this.isOrganizer,
    this.avatarUrl,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    isOrganizer: json['is_organizer'] as bool,
  );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isOrganizer;
}
