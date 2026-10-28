import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x5football/app.dart';
import 'package:x5football/config/app_config.dart';
import 'package:x5football/data/app_error.dart';
import 'package:x5football/models/profile.dart';

import 'fakes.dart';

const _config = AppConfig(
  environment: AppEnvironment.test,
  supabaseUrl: 'http://localhost:54321',
  supabasePublishableKey: 'sb_publishable_test',
);

Future<void> _pumpApp(
  WidgetTester tester,
  FakeAuthRepository auth,
  FakeProfileRepository profiles,
) async {
  await tester.pumpWidget(
    X5FootballApp(
      config: _config,
      auth: auth,
      profiles: profiles,
      matches: FakeMatchRepository(),
      geocoding: FakeGeocodingRepository(),
      location: FakeLocationService(),
      notifications: FakeNotificationRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('connexion', () {
    testWidgets('un utilisateur déconnecté voit l\'écran de connexion', (
      tester,
    ) async {
      await _pumpApp(tester, FakeAuthRepository(), FakeProfileRepository());
      expect(find.text('Recevoir un code'), findsOneWidget);
    });

    testWidgets('un e-mail invalide n\'envoie pas de code', (tester) async {
      final auth = FakeAuthRepository();
      await _pumpApp(tester, auth, FakeProfileRepository());

      await tester.enterText(find.byType(TextFormField), 'pas-un-email');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();

      expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('code reçu puis vérifié : passage à la création du profil', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await _pumpApp(tester, auth, FakeProfileRepository());

      await tester.enterText(find.byType(TextFormField), ' joueur@test.fr ');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Code envoyé à joueur@test.fr'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(auth.calls, [
        'send:joueur@test.fr',
        'verify:joueur@test.fr:123456',
      ]);
      expect(find.text('Votre profil'), findsOneWidget);
    });

    testWidgets('un code refusé affiche le message du serveur', (tester) async {
      final auth = FakeAuthRepository()
        ..verifyError = const AppError(
          'OTP_INVALID',
          'Code invalide ou expiré.',
        );
      await _pumpApp(tester, auth, FakeProfileRepository());

      await tester.enterText(find.byType(TextFormField), 'joueur@test.fr');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Code invalide ou expiré.'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });
  });

  group('création du profil', () {
    testWidgets('impossible de continuer sans attester sa majorité', (
      tester,
    ) async {
      final profiles = FakeProfileRepository();
      await _pumpApp(tester, FakeAuthRepository(signedIn: true), profiles);

      await tester.enterText(find.byType(TextFormField), 'Nabil');
      final button = find.widgetWithText(FilledButton, 'Continuer');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('profil complété : accès à l\'accueil', (tester) async {
      final profiles = FakeProfileRepository();
      await _pumpApp(tester, FakeAuthRepository(signedIn: true), profiles);

      await tester.enterText(find.byType(TextFormField), '  Nabil ');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(profiles.calls, ['complete:Nabil:true']);
      expect(find.text('Créer un match'), findsOneWidget);
    });

    testWidgets('un nom trop court est refusé avant l\'envoi', (tester) async {
      final profiles = FakeProfileRepository();
      await _pumpApp(tester, FakeAuthRepository(signedIn: true), profiles);

      await tester.enterText(find.byType(TextFormField), 'N');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Au moins 2 caractères.'), findsOneWidget);
      expect(profiles.calls, isEmpty);
    });

    testWidgets('une erreur serveur est affichée', (tester) async {
      final profiles = FakeProfileRepository()
        ..completeError = const AppError(
          'AGE_NOT_CONFIRMED',
          'Réservé aux 18 ans et plus.',
        );
      await _pumpApp(tester, FakeAuthRepository(signedIn: true), profiles);

      await tester.enterText(find.byType(TextFormField), 'Nabil');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Réservé aux 18 ans et plus.'), findsOneWidget);
    });

    testWidgets('une session expirée ramène à l\'écran de connexion', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedIn: true);
      final profiles = FakeProfileRepository()
        ..completeError = const AppError('AUTH_REQUIRED', 'Reconnectez-vous.');
      await _pumpApp(tester, auth, profiles);

      await tester.enterText(find.byType(TextFormField), 'Nabil');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signOut']);
      expect(find.text('Recevoir un code'), findsOneWidget);
    });
  });

  group('compte', () {
    testWidgets('un compte suspendu n\'accède pas à l\'accueil', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(
        profile: const Profile(
          id: 'me',
          displayName: 'Nabil',
          accountStatus: AccountStatus.suspended,
        ),
      );
      await _pumpApp(tester, FakeAuthRepository(signedIn: true), profiles);

      expect(find.text('Votre compte est suspendu.'), findsOneWidget);
      expect(find.text('Créer un match'), findsNothing);
    });

    Future<void> openProfile(
      WidgetTester tester,
      FakeAuthRepository auth,
      FakeProfileRepository profiles,
    ) async {
      await _pumpApp(tester, auth, profiles);
      await tester.tap(find.byTooltip('Mon profil'));
      await tester.pumpAndSettle();
    }

    testWidgets('modification du nom', (tester) async {
      final profiles = FakeProfileRepository(
        profile: const Profile(id: 'me', displayName: 'Nabil'),
      );
      await openProfile(tester, FakeAuthRepository(signedIn: true), profiles);

      await tester.enterText(find.byType(TextFormField), 'Nabil B.');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(profiles.calls, ['update:Nabil B.']);
      expect(find.text('Profil enregistré.'), findsOneWidget);
    });

    testWidgets('déconnexion', (tester) async {
      final auth = FakeAuthRepository(signedIn: true);
      final profiles = FakeProfileRepository(
        profile: const Profile(id: 'me', displayName: 'Nabil'),
      );
      await openProfile(tester, auth, profiles);

      await tester.tap(find.text('Déconnexion'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signOut']);
      expect(find.text('Recevoir un code'), findsOneWidget);
    });

    testWidgets('la suppression de compte exige une confirmation', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedIn: true);
      final profiles = FakeProfileRepository(
        profile: const Profile(id: 'me', displayName: 'Nabil'),
      );
      await openProfile(tester, auth, profiles);

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(profiles.calls, isEmpty);

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Supprimer mon compte').last,
      );
      await tester.pumpAndSettle();

      expect(profiles.calls, ['delete']);
      expect(auth.calls, ['signOut']);
      expect(find.text('Recevoir un code'), findsOneWidget);
    });
  });
}
