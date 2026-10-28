/// Notification affichée dans l'application. Le titre et le texte sont rédigés par le serveur.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.date,
    required this.isRead,
    this.matchId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        matchId: json['match_id'] as String?,
        date: DateTime.parse(json['scheduled_for'] as String).toLocal(),
        isRead: json['read_at'] != null,
      );

  final String id;

  /// Ex. `transfer_proposed`, `match_cancelled`, `match_reminder`.
  final String type;
  final String title;
  final String body;
  final String? matchId;
  final DateTime date;
  final bool isRead;
}
