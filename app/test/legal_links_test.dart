import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x5football/ui/legal_links.dart';

void main() {
  testWidgets('les liens légaux ouvrent les pages publiées', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegalLinks(
            openUrl: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Conditions d\'utilisation'));
    await tester.tap(find.text('Politique de confidentialité'));
    expect(opened, [termsUri, privacyPolicyUri]);
    expect(privacyPolicyUri.scheme, 'https');
    expect(
      privacyPolicyUri.toString(),
      'https://nabil67.github.io/x5football/confidentialite.html',
    );
  });
}
