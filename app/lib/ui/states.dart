import 'package:flutter/material.dart';

import '../data/app_error.dart';

/// Squelette de liste pendant un chargement (annoncé « Chargement » aux lecteurs d'écran).
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.items = 4});

  final int items;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: 'Chargement',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(200, 18),
                const SizedBox(height: 8),
                bar(260, 14),
                const SizedBox(height: 6),
                bar(140, 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur centré, pour un contenu unique (ex. détail d'un match).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
  );
}

/// Message centré avec icône et action facultative (liste vide, erreur, hors ligne).
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Erreur : icône « hors ligne » si le réseau est absent, bouton « Réessayer ».
  factory MessageView.error(Object? error, {required VoidCallback onRetry}) {
    final appError = error is AppError ? error : null;
    return MessageView(
      icon: appError?.isOffline ?? false
          ? Icons.cloud_off
          : Icons.error_outline,
      message: appError?.message ?? AppError.genericMessage,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Défilable : reste lisible avec un grand texte et compatible « tirer pour actualiser ».
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
