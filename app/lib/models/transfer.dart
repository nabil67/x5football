/// Proposition de transfert d'organisation (vue `transfer_details`).
/// Visible uniquement de l'organisateur qui propose et du participant ciblé.
class Transfer {
  const Transfer({
    required this.id,
    required this.matchId,
    required this.toUserId,
    required this.expiresAt,
    this.fromName,
    this.toName,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
    id: json['id'] as String,
    matchId: json['match_id'] as String,
    toUserId: json['to_user_id'] as String,
    fromName: json['from_name'] as String?,
    toName: json['to_name'] as String?,
    expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
  );

  final String id;
  final String matchId;
  final String toUserId;

  /// `null` si le compte n'est plus actif.
  final String? fromName;
  final String? toName;
  final DateTime expiresAt;
}
