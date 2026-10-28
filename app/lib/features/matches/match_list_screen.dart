import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/match_repository.dart';
import '../../models/match.dart';
import '../../ui/formatters.dart';
import 'match_detail_screen.dart';
import 'match_form_screen.dart';

/// Accueil : matchs à venir et matchs de l'utilisateur.
class MatchListScreen extends StatefulWidget {
  const MatchListScreen({
    super.key,
    required this.matches,
    required this.profileButton,
  });

  final MatchRepository matches;

  /// Accès au profil, fourni par l'écran parent.
  final Widget profileButton;

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  // Change à chaque rafraîchissement pour recharger les deux onglets.
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  Future<void> _openMatch(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(matchId: id, matches: widget.matches),
      ),
    );
    _refresh();
  }

  Future<void> _createMatch() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MatchFormScreen(matches: widget.matches),
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
          actions: [widget.profileButton],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'À venir'),
              Tab(text: 'Mes matchs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MatchList(
              key: ValueKey('upcoming-$_refreshKey'),
              load: widget.matches.listUpcoming,
              emptyMessage:
                  'Aucun match à venir pour le moment.\nCréez le premier !',
              onTap: _openMatch,
            ),
            _MatchList(
              key: ValueKey('mine-$_refreshKey'),
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
          return _CenteredMessage(message: message, onRetry: _reload);
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
  const MatchTile({super.key, required this.match, required this.onTap});

  final Match match;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final location = match.isLocationConfirmed
        ? match.locationName!
        : 'Lieu à confirmer${match.locationName != null ? ' · ${match.locationName}' : ''}';
    final status = switch (match.displayStatus) {
      MatchDisplayStatus.open =>
        '${match.spotsLeft} place${match.spotsLeft > 1 ? 's' : ''} restante${match.spotsLeft > 1 ? 's' : ''}',
      final other => other.label,
    };
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

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message, required this.onRetry});

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
