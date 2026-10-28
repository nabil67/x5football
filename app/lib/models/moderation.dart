/// Motifs de signalement (enum `report_reason` côté serveur).
enum ReportReason {
  inappropriateBehavior('inappropriate_behavior', 'Comportement inapproprié'),
  harassment('harassment', 'Harcèlement ou insultes'),
  spam('spam', 'Spam ou publicité'),
  fakeMatch('fake_match', 'Faux match ou informations trompeuses'),
  dangerous('dangerous', 'Situation dangereuse'),
  other('other', 'Autre');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;
}

class BlockedUser {
  const BlockedUser({required this.userId, this.displayName, this.avatarUrl});

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  final String userId;

  /// `null` si le compte n'est plus actif.
  final String? displayName;
  final String? avatarUrl;
}
