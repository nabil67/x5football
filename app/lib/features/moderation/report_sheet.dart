import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/moderation_repository.dart';
import '../../models/moderation.dart';

/// Ouvre le formulaire de signalement d'un joueur ([userId]) ou d'un match ([matchId]).
/// Affiche la confirmation ou l'erreur ; renvoie `true` si le signalement est parti.
Future<bool> showReportSheet(
  BuildContext context, {
  required ModerationRepository moderation,
  required String targetLabel,
  String? userId,
  String? matchId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(
      moderation: moderation,
      targetLabel: targetLabel,
      userId: userId,
      matchId: matchId,
    ),
  );
  if (sent == true) {
    // Aucune promesse de sanction automatique : une personne examine chaque signalement.
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Merci. Votre signalement a été transmis et sera examiné.',
        ),
      ),
    );
  }
  return sent == true;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.moderation,
    required this.targetLabel,
    this.userId,
    this.matchId,
  });

  final ModerationRepository moderation;
  final String targetLabel;
  final String? userId;
  final String? matchId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _comment = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.moderation.report(
        reason: _reason!,
        userId: widget.userId,
        matchId: widget.matchId,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        // Le formulaire reste visible au-dessus du clavier.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Signaler ${widget.targetLabel}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Votre signalement reste confidentiel et sera examiné par une personne.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        enabled: !_busy,
                        title: Text(reason.label),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _comment,
                enabled: !_busy,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Précisions (facultatif)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _busy || _reason == null ? null : _send,
                child: const Text('Envoyer le signalement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
