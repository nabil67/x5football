import 'package:flutter/material.dart';

import 'maps_launcher.dart';

/// Pages publiées par GitHub Pages depuis le dossier `site/` du dépôt.
const legalBaseUrl = 'https://nabil67.github.io/x5football';

final privacyPolicyUri = Uri.parse('$legalBaseUrl/confidentialite.html');
final termsUri = Uri.parse('$legalBaseUrl/conditions.html');

/// Liens vers les conditions d'utilisation et la politique de confidentialité.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.openUrl = openExternalUrl});

  final OpenExternalUrl openUrl;

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await openUrl(uri)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir la page : $uri')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => _open(context, termsUri),
          child: const Text('Conditions d\'utilisation'),
        ),
        TextButton(
          onPressed: () => _open(context, privacyPolicyUri),
          child: const Text('Politique de confidentialité'),
        ),
      ],
    );
  }
}
