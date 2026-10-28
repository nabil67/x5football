import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../data/notification_repository.dart';
import '../../models/match.dart';
import '../../ui/formatters.dart';
import '../notifications/notifications_screen.dart';
import 'match_detail_screen.dart';
import 'match_form_screen.dart';
import 'nearby_matches_view.dart';

/// Accueil : matchs à proximité et matchs de l'utilisateur.
class MatchListScreen extends StatefulWidget {
  const MatchListScreen({
    super.key,
    required this.matches,
    required this.geocoding,
    required this.location,
    required this.notifications,
    required this.profileButton,
  });

  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;
  final NotificationRepository notifications;

  /// Accès au profil, fourni par l'écran parent.
  final Widget profileButton;

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen>
    with WidgetsBindingObserver {
  // Change à chaque retour d'un match pour recharger les deux onglets.
  int _refreshToken = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final count = await widget.notifications.unreadCount();
      if (mounted) setState(() => _unread = count);
    } on AppError {
      // Compteur indicatif : une erreur réseau ne doit pas gêner l'accueil.
    }
  }

  void _refresh() {
    setState(() => _refreshToken++);
    _loadUnread();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          notifications: widget.notifications,
          onOpenMatch: _openMatch,
        ),
      ),
    );
    _loadUnread();
  }

  Future<void> _openMatch(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(
          matchId: id,
          matches: widget.matches,
          geocoding: widget.geocoding,
          location: widget.location,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _createMatch() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MatchFormScreen(
          matches: widget.matches,
          geocoding: widget.geocoding,
          location: widget.location,
        ),
      ),
    );
    if (id != null) await _openMatch(id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('x5football'),
          actions: [
            IconButton(
              tooltip: _unread == 0
                  ? 'Notifications'
                  : 'Notifications, $_unread non lue${_unread > 1 ? 's' : ''}',
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text(_unread > 99 ? '99+' : '$_unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            widget.profileButton,
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'À proximité'),
              Tab(text: 'Mes matchs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NearbyMatchesView(
              matches: widget.matches,
              geocoding: widget.geocoding,
              location: widget.location,
              refreshToken: _refreshToken,
              onTap: _openMatch,
            ),
            _MatchList(
              key: ValueKey('mine-$_refreshToken'),
              load: widget.matches.listMine,
              emptyMessage: 'Vous ne participez à aucun match à venir.',
              onTap: _openMatch,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createMatch,
          icon: const Icon(Icons.add),
          label: const Text('Créer un match'),
        ),
      ),
    );
  }
}

class _MatchList extends StatefulWidget {
  const _MatchList({
    super.key,
    required this.load,
    required this.emptyMessage,
    required this.onTap,
  });

  final Future<List<Match>> Function() load;
  final String emptyMessage;
  final ValueChanged<String> onTap;

  @override
  State<_MatchList> createState() => _MatchListState();
}

class _MatchListState extends State<_MatchList> {
  late Future<List<Match>> _future = widget.load();

  Future<void> _reload() async {
    final future = widget.load();
    setState(() {
      _future = future;
    });
    await future.catchError((_) => <Match>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Match>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
          );
        }
        if (snapshot.hasError) {
          final message = snapshot.error is AppError
              ? (snapshot.error as AppError).message
              : AppError.genericMessage;
          return CenteredMessage(message: message, onRetry: _reload);
        }
        final matches = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: matches.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Text(widget.emptyMessage, textAlign: TextAlign.center),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: matches.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      MatchTile(match: matches[i], onTap: widget.onTap),
                ),
        );
      },
    );
  }
}

class MatchTile extends StatelessWidget {
  const MatchTile({
    super.key,
    required this.match,
    required this.onTap,
    this.distanceKm,
  });

  final Match match;
  final ValueChanged<String> onTap;

  /// Distance au point de recherche, affichée si connue.
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final status = switch (match.displayStatus) {
      MatchDisplayStatus.open =>
        '${match.spotsLeft} place${match.spotsLeft > 1 ? 's' : ''} restante${match.spotsLeft > 1 ? 's' : ''}',
      final other => other.label,
    };
    final location = distanceKm == null
        ? match.locationName
        : '${formatDistance(distanceKm!)} · ${match.locationName}';
    return ListTile(
      onTap: () => onTap(match.id),
      title: Text(match.title),
      subtitle: Text('${formatMatchDate(match.startsAt)}\n$location'),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            match.format.code,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(status, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
