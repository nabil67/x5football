import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../data/notification_repository.dart';
import '../../models/match.dart';
import '../../ui/formatters.dart';
import '../../ui/states.dart';
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
          return const LoadingList();
        }
        if (snapshot.hasError) {
          return MessageView.error(snapshot.error, onRetry: _reload);
        }
        final matches = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: matches.isEmpty
              ? MessageView(
                  icon: Icons.sports_soccer,
                  message: widget.emptyMessage,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: matches.length,
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

  String get _spots => match.displayStatus == MatchDisplayStatus.open
      ? '${match.spotsLeft} place${match.spotsLeft > 1 ? 's' : ''} restante${match.spotsLeft > 1 ? 's' : ''}'
      : match.displayStatus.label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = distanceKm == null
        ? match.locationName
        : '${formatDistance(distanceKm!)} · ${match.locationName}';
    final role = match.isOrganizer
        ? 'Organisateur'
        : match.isParticipant
        ? 'Inscrit'
        : null;
    final fill = match.capacity == 0
        ? 0.0
        : (match.participantCount / match.capacity).clamp(0.0, 1.0);

    // Une seule annonce cohérente (contenu + action) pour les lecteurs d'écran.
    return MergeSemantics(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(match.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        match.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      match.format.code,
                      semanticsLabel: match.format.label,
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(formatMatchDate(match.startsAt)),
                Text(
                  location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (match.displayStatus != MatchDisplayStatus.open)
                      StatusBadge(match.displayStatus),
                    if (role != null) _Badge(label: role, icon: Icons.check),
                    Text(_spots, style: theme.textTheme.bodySmall),
                  ],
                ),
                if (match.displayStatus == MatchDisplayStatus.open ||
                    match.displayStatus == MatchDisplayStatus.full) ...[
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: fill, minHeight: 6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de statut, masquée pour un match ouvert (cas normal).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final MatchDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      MatchDisplayStatus.open => const SizedBox.shrink(),
      MatchDisplayStatus.cancelled => _Badge(
        label: status.label,
        icon: Icons.event_busy,
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      MatchDisplayStatus.full => _Badge(
        label: status.label,
        icon: Icons.group,
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ),
      _ => _Badge(label: status.label, icon: Icons.schedule),
    };
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: fg)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
