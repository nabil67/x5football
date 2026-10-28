import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../models/match.dart';
import '../../ui/formatters.dart';
import '../../ui/maps_launcher.dart';
import 'match_form_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.matches,
    required this.geocoding,
    required this.location,
    this.openUrl = openExternalUrl,
  });

  final String matchId;
  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;
  final OpenExternalUrl openUrl;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late Future<(Match, List<Participant>)> _future = _load();
  bool _busy = false;

  Future<(Match, List<Participant>)> _load() async {
    final results = await Future.wait([
      widget.matches.getMatch(widget.matchId),
      widget.matches.listParticipants(widget.matchId),
    ]);
    return (results[0] as Match, results[1] as List<Participant>);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _edit(Match match) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MatchFormScreen(
          matches: widget.matches,
          geocoding: widget.geocoding,
          location: widget.location,
          initial: match,
        ),
      ),
    );
    if (saved != null) _reload();
  }

  Future<void> _openInMaps(Match match) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await widget.openUrl(mapsUri(match.location))) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir l\'application de cartes.'),
        ),
      );
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.matches.joinMatch(widget.matchId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Vous êtes inscrit. Bon match !')),
      );
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Rechargé dans tous les cas : un refus (complet, annulé…) signale un écran périmé.
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter ce match ?'),
        content: const Text('Votre place sera libérée pour un autre joueur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rester inscrit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter le match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.matches.leaveMatch(widget.matchId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Vous avez quitté le match.')),
      );
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce match ?'),
        content: const Text(
          'Les inscriptions seront fermées et le match apparaîtra comme annulé '
          'pour tous les participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler le match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.matches.cancelMatch(widget.matchId);
      messenger.showSnackBar(const SnackBar(content: Text('Match annulé.')));
      _reload();
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: FutureBuilder(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is AppError ? error.message : AppError.genericMessage,
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          final (match, participants) = snapshot.data!;
          return _MatchDetails(
            match: match,
            participants: participants,
            busy: _busy,
            onEdit: () => _edit(match),
            onCancel: _cancel,
            onJoin: _join,
            onLeave: _leave,
            onOpenInMaps: () => _openInMaps(match),
          );
        },
      ),
    );
  }
}

class _MatchDetails extends StatelessWidget {
  const _MatchDetails({
    required this.match,
    required this.participants,
    required this.busy,
    required this.onEdit,
    required this.onCancel,
    required this.onJoin,
    required this.onLeave,
    required this.onOpenInMaps,
  });

  final Match match;
  final List<Participant> participants;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onOpenInMaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(match.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        if (match.displayStatus != MatchDisplayStatus.open)
          Text(
            match.displayStatus.label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: match.displayStatus == MatchDisplayStatus.cancelled
                  ? theme.colorScheme.error
                  : null,
            ),
          ),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.event, text: formatMatchDate(match.startsAt)),
        _InfoRow(
          icon: Icons.timer_outlined,
          text: formatDuration(match.durationMinutes),
        ),
        _InfoRow(icon: Icons.place_outlined, text: match.locationName),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onOpenInMaps,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ouvrir dans Maps'),
          ),
        ),
        _InfoRow(
          icon: Icons.sports_soccer,
          text: '${match.format.label} · ${match.skillLevel.label}',
        ),
        _InfoRow(
          icon: Icons.group_outlined,
          text:
              '${match.participantCount} / ${match.capacity} joueurs'
              '${match.displayStatus == MatchDisplayStatus.open ? ' · ${match.spotsLeft} place${match.spotsLeft > 1 ? 's' : ''} libre${match.spotsLeft > 1 ? 's' : ''}' : ''}',
        ),
        if (match.estimatedCostPerPlayer != null)
          _InfoRow(
            icon: Icons.euro,
            text:
                'Coût estimé par joueur : ${formatCost(match.estimatedCostPerPlayer!, match.currency)}'
                ' (à régler sur place, indicatif)',
          )
        else if (match.estimatedTotalCost != null)
          _InfoRow(
            icon: Icons.euro,
            text:
                'Coût total estimé du terrain : ${formatCost(match.estimatedTotalCost!, match.currency)}'
                ' (à partager, indicatif)',
          ),
        if (match.description != null) ...[
          const SizedBox(height: 12),
          Text(match.description!),
        ],
        if (!match.isOrganizer && match.isEditable) ...[
          const SizedBox(height: 16),
          if (match.isParticipant) ...[
            Text(
              'Vous êtes inscrit à ce match.',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onLeave,
              icon: const Icon(Icons.logout),
              label: const Text('Quitter le match'),
            ),
          ] else if (match.displayStatus == MatchDisplayStatus.open)
            FilledButton.icon(
              onPressed: busy ? null : onJoin,
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Rejoindre le match'),
            )
          else
            const FilledButton(onPressed: null, child: Text('Match complet')),
        ],
        if (match.isOrganizer && match.isEditable) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annuler le match'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Participants', style: theme.textTheme.titleMedium),
        for (final p in participants)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(p.displayName.characters.first.toUpperCase()),
            ),
            title: Text(p.displayName),
            subtitle: p.isOrganizer ? const Text('Organisateur') : null,
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
