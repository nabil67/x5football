import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/moderation_repository.dart';
import '../../models/moderation.dart';
import '../../ui/states.dart';
import '../../ui/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, required this.moderation});

  final ModerationRepository moderation;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<BlockedUser>> _future = widget.moderation.listBlocked();

  void _reload() => setState(() {
    _future = widget.moderation.listBlocked();
  });

  Future<void> _unblock(BlockedUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.moderation.unblock(user.userId);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${user.displayName ?? 'Ce joueur'} est débloqué.'),
        ),
      );
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Joueurs bloqués')),
      body: FutureBuilder<List<BlockedUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingList(items: 2);
          }
          if (snapshot.hasError) {
            return MessageView.error(snapshot.error, onRetry: _reload);
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const MessageView(
              icon: Icons.block,
              message: 'Vous n\'avez bloqué personne.',
            );
          }
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ces joueurs ne peuvent pas rejoindre vos matchs, et leurs '
                  'matchs n\'apparaissent pas dans vos recherches. '
                  'Ils n\'en sont pas informés.',
                ),
              ),
              for (final user in users)
                ListTile(
                  leading: UserAvatar(
                    name: user.displayName ?? '?',
                    path: user.avatarUrl,
                  ),
                  title: Text(user.displayName ?? 'Compte supprimé'),
                  trailing: TextButton(
                    onPressed: () => _unblock(user),
                    child: const Text('Débloquer'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
