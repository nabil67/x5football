import 'package:flutter/material.dart';

import '../../models/match.dart';
import '../../models/transfer.dart';
import '../../ui/formatters.dart';

/// Transfert d'organisation sur l'écran d'un match.
///
/// - Organisateur sans proposition : bouton « Transmettre l'organisation ».
/// - Organisateur avec proposition : destinataire, échéance, retrait possible.
/// - Participant ciblé (seul autre à voir la proposition) : accepter ou refuser.
class TransferSection extends StatelessWidget {
  const TransferSection({
    super.key,
    required this.match,
    required this.transfer,
    required this.hasCandidates,
    required this.busy,
    required this.onPropose,
    required this.onCancel,
    required this.onRespond,
  });

  final Match match;
  final Transfer? transfer;

  /// Au moins un autre participant peut recevoir l'organisation.
  final bool hasCandidates;
  final bool busy;
  final VoidCallback onPropose;
  final VoidCallback onCancel;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transfer = this.transfer;

    if (transfer == null) {
      if (!match.isOrganizer || !hasCandidates) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          onPressed: busy ? null : onPropose,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Transmettre l\'organisation'),
        ),
      );
    }

    final expires = 'Expire le ${formatMatchDate(transfer.expiresAt)}.';
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: match.isOrganizer
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proposition envoyée à ${transfer.toName ?? 'un joueur'}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('En attente de sa réponse. $expires'),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: busy ? null : onCancel,
                      child: const Text('Retirer la proposition'),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transfer.fromName ?? 'L\'organisateur'} vous propose '
                    'd\'organiser ce match',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Si vous acceptez, vous pourrez le modifier ou l\'annuler. '
                    '$expires',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => onRespond(false),
                          child: const Text('Refuser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => onRespond(true),
                          child: const Text('Accepter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
