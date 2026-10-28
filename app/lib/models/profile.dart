enum AccountStatus { active, suspended, pendingDeletion, deleted }

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.accountStatus = AccountStatus.active,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    accountStatus: switch (json['account_status']) {
      'active' => AccountStatus.active,
      'suspended' => AccountStatus.suspended,
      'pending_deletion' => AccountStatus.pendingDeletion,
      _ => AccountStatus.deleted,
    },
  );

  final String id;
  final String displayName;
  final String? avatarUrl;
  final AccountStatus accountStatus;

  bool get isActive => accountStatus == AccountStatus.active;

  /// Règle de validation alignée sur la contrainte `users_display_name_valid`.
  /// Renvoie un message d'erreur, ou `null` si le nom est valide.
  static String? validateDisplayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 2) return 'Au moins 2 caractères.';
    if (name.length > 40) return '40 caractères maximum.';
    return null;
  }
}
