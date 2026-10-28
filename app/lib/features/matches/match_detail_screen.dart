import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../data/moderation_repository.dart';
import '../../models/match.dart';
import '../../models/transfer.dart';
import '../../ui/formatters.dart';
import '../../ui/maps_launcher.dart';
import '../../ui/states.dart';
import '../../ui/user_avatar.dart';
import 'match_list_screen.dart' show StatusBadge;
import '../moderation/report_sheet.dart';
import 'match_form_screen.dart';
import 'transfer_section.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.matches,
    required this.geocoding,
    required this.location,
    required this.moderation,
    this.openUrl = openExternalUrl,
  });

  final String matchId;
  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;
  final ModerationRepository moderation;
  final OpenExternalUrl openUrl;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late Future<_DetailData> _future = _load();
  bool _busy = false;

  Future<_DetailData> _load() async {
    final results = await Future.wait([
      widget.matches.getMatch(widget.matchId),
      widget.matches.listParticipants(widget.matchId),
      widget.matches.pendingTransfer(widget.matchId),
    ]);
    return (
      match: results[0] as Match,
      participants: results[1] as List<Participant>,
      transfer: results[2] as Transfer?,
    );
  }

  /// Exécute une action, affiche son résultat puis recharge l'écran dans tous les cas :
  /// un refus du serveur (match complet, proposition expirée…) signale un écran périmé.
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
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

  Future<bool> _confirm({
    required String title,
    required String content,
    required String cancelLabel,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _join() => _run(
    () => widget.matches.joinMatch(widget.matchId),
    'Vous êtes inscrit. Bon match !',
  );

  Future<void> _leave() async {
    if (!await _confirm(
      title: 'Quitter ce match ?',
      content: 'Votre place sera libérée pour un autre joueur.',
      cancelLabel: 'Rester inscrit',
      confirmLabel: 'Quitter le match',
    )) {
      return;
    }
    await _run(
      () => widget.matches.leaveMatch(widget.matchId),
      'Vous avez quitté le match.',
    );
  }

  Future<void> _cancel() async {
    if (!await _confirm(
      title: 'Annuler ce match ?',
      content:
          'Les inscriptions seront fermées et le match apparaîtra comme annulé '
          'pour tous les participants.',
      cancelLabel: 'Retour',
      confirmLabel: 'Annuler le match',
    )) {
      return;
    }
    await _run(
      () => widget.matches.cancelMatch(widget.matchId),
      'Match annulé.',
    );
  }

  Future<void> _proposeTransfer(List<Participant> participants) async {
    final candidates = participants.where((p) => !p.isOrganizer).toList();
    final target = await showDialog<Participant>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('À qui transmettre l\'organisation ?'),
        children: [
          for (final p in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Text(p.displayName),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    if (!await _confirm(
      title: 'Proposer à ${target.displayName} ?',
      content:
          '${target.displayName} deviendra organisateur s\'il accepte. '
          'Vous resterez inscrit comme joueur. La proposition expire après '
          '48 h, et au plus tard au début du match.',
      cancelLabel: 'Retour',
      confirmLabel: 'Envoyer la proposition',
    )) {
      return;
    }
    await _run(
      () => widget.matches.proposeTransfer(widget.matchId, target.userId),
      'Proposition envoyée à ${target.displayName}.',
    );
  }

  Future<void> _reportUser(Participant p) => showReportSheet(
    context,
    moderation: widget.moderation,
    targetLabel: p.displayName,
    userId: p.userId,
  );

  Future<void> _blockUser(Participant p) async {
    if (!await _confirm(
      title: 'Bloquer ${p.displayName} ?',
      content:
          '${p.displayName} ne pourra plus rejoindre les matchs que vous organisez, '
          'et vous ne verrez plus les siens dans vos recherches. '
          'Il n\x27en sera pas informé. Vous pourrez le débloquer depuis votre profil.',
      cancelLabel: 'Retour',
      confirmLabel: 'Bloquer',
    )) {
      return;
    }
    await _run(
      () => widget.moderation.block(p.userId),
      '${p.displayName} est bloqué.',
    );
  }

  Future<void> _cancelTransfer() => _run(
    () => widget.matches.cancelTransfer(widget.matchId),
    'Proposition retirée.',
  );

  Future<void> _respondTransfer(Transfer transfer, {required bool accept}) =>
      _run(
        () => widget.matches.respondTransfer(transfer.id, accept: accept),
        accept ? 'Vous organisez désormais ce match.' : 'Proposition refusée.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match'),
        actions: [
          // Signaler le match : proposé à tous sauf à son organisateur.
          FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              final match = snapshot.data?.match;
              if (match == null || match.isOrganizer) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                tooltip: 'Plus d\x27options',
                onSelected: (_) => showReportSheet(
                  context,
                  moderation: widget.moderation,
                  targetLabel: 'ce match',
                  matchId: match.id,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('Signaler ce match'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          // Pendant un rechargement, l'écran précédent reste affiché.
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return MessageView.error(snapshot.error, onRetry: _reload);
          }
          final (:match, :participants, :transfer) = snapshot.data!;
          return _MatchDetails(
            match: match,
            participants: participants,
            transfer: transfer,
            busy: _busy,
            onEdit: () => _edit(match),
            onCancel: _cancel,
            onJoin: _join,
            onLeave: _leave,
            onOpenInMaps: () => _openInMaps(match),
            onProposeTransfer: () => _proposeTransfer(participants),
            onCancelTransfer: _cancelTransfer,
            onRespondTransfer: (accept) =>
                _respondTransfer(transfer!, accept: accept),
            onReportUser: _reportUser,
            onBlockUser: _blockUser,
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
    required this.transfer,
    required this.busy,
    required this.onEdit,
    required this.onCancel,
    required this.onJoin,
    required this.onLeave,
    required this.onOpenInMaps,
    required this.onProposeTransfer,
    required this.onCancelTransfer,
    required this.onRespondTransfer,
    required this.onReportUser,
    required this.onBlockUser,
  });

  final Match match;
  final List<Participant> participants;
  final Transfer? transfer;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onOpenInMaps;
  final VoidCallback onProposeTransfer;
  final VoidCallback onCancelTransfer;
  final ValueChanged<bool> onRespondTransfer;
  final ValueChanged<Participant> onReportUser;
  final ValueChanged<Participant> onBlockUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(match.title, style: theme.textTheme.headlineSmall),
        ),
        if (match.displayStatus != MatchDisplayStatus.open) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(match.displayStatus),
          ),
        ],
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
        if (match.isEditable)
          TransferSection(
            match: match,
            transfer: transfer,
            hasCandidates: participants.any((p) => !p.isOrganizer),
            busy: busy,
            onPropose: onProposeTransfer,
            onCancel: onCancelTransfer,
            onRespond: onRespondTransfer,
          ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text('Participants', style: theme.textTheme.titleMedium),
        ),
        for (final p in participants)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UserAvatar(name: p.displayName, path: p.avatarUrl),
            title: Text(p.displayName),
            subtitle: p.isOrganizer ? const Text('Organisateur') : null,
            trailing: p.isMe
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Options pour ${p.displayName}',
                    onSelected: (action) =>
                        action == 'block' ? onBlockUser(p) : onReportUser(p),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('Signaler')),
                      PopupMenuItem(value: 'block', child: Text('Bloquer')),
                    ],
                  ),
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

typedef _DetailData = ({
  Match match,
  List<Participant> participants,
  Transfer? transfer,
});
