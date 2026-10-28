import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../ui/formatters.dart';

/// Liste des notifications ; à l'ouverture, toutes sont marquées comme lues.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.notifications,
    required this.onOpenMatch,
  });

  final NotificationRepository notifications;
  final ValueChanged<String> onOpenMatch;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future = _load();

  Future<List<AppNotification>> _load() async {
    final items = await widget.notifications.list();
    // Les non-lues restent mises en avant pendant cette visite.
    if (items.any((n) => !n.isRead)) {
      await widget.notifications.markAllRead().catchError((_) {});
    }
    return items;
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future.catchError((_) => <AppNotification>[]);
  }

  static IconData _icon(String type) => switch (type) {
    'match_reminder' => Icons.alarm,
    'match_cancelled' => Icons.event_busy,
    'match_updated' => Icons.edit_calendar,
    _ => Icons.swap_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: Text(
                  '${error is AppError ? error.message : AppError.genericMessage}\nRéessayer',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final items = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Text('Aucune notification.', textAlign: TextAlign.center),
                    ],
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      return ListTile(
                        leading: Icon(_icon(n.type)),
                        title: Text(
                          n.title,
                          style: n.isRead
                              ? null
                              : const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${n.body}\n${formatMatchDate(n.date)}'),
                        isThreeLine: true,
                        trailing: n.isRead
                            ? null
                            : Icon(
                                Icons.circle,
                                size: 10,
                                color: theme.colorScheme.primary,
                                semanticLabel: 'Non lue',
                              ),
                        onTap: n.matchId == null
                            ? null
                            : () => widget.onOpenMatch(n.matchId!),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
