import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x5football/data/app_error.dart';
import 'package:x5football/features/matches/match_detail_screen.dart';
import 'package:x5football/features/matches/match_form_screen.dart';
import 'package:x5football/features/matches/match_list_screen.dart';
import 'package:x5football/models/match.dart';

import 'fakes.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('fr', 'FR'),
  supportedLocales: const [Locale('fr', 'FR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

final _now = DateTime(2026, 10, 28, 10);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('MatchInput', () {
    MatchInput input(LocationMode mode) => MatchInput(
      title: 'Foot',
      startsAt: DateTime.utc(2026, 11, 1, 14),
      durationMinutes: 90,
      capacity: 10,
      format: MatchFormat.fiveASide,
      skillLevel: SkillLevel.all,
      locationMode: mode,
      locationName: 'Stade',
      latitude: 47.39,
      longitude: 0.69,
    );

    test('un lieu à définir n\'envoie jamais de position', () {
      final json = input(LocationMode.toDefine).toJson();
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
      expect(json['location_mode'], 'to_define');
    });

    test('un terrain précis envoie sa position et une date UTC', () {
      final json = input(LocationMode.fixed).toJson();
      expect(json['latitude'], 47.39);
      expect(json['starts_at'], '2026-11-01T14:00:00.000Z');
    });
  });

  group('liste', () {
    testWidgets('affiche « Lieu à confirmer » et les places restantes', (
      tester,
    ) async {
      final repo = FakeMatchRepository(
        upcoming: [fakeMatch(participantCount: 3)],
      );
      await tester.pumpWidget(
        _wrap(MatchListScreen(matches: repo, profileButton: const SizedBox())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Foot du dimanche'), findsOneWidget);
      expect(find.textContaining('Lieu à confirmer'), findsOneWidget);
      expect(find.text('7 places restantes'), findsOneWidget);
    });

    testWidgets('liste vide', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MatchListScreen(
            matches: FakeMatchRepository(),
            profileButton: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucun match à venir'), findsOneWidget);
    });
  });

  testWidgets('tirer vers le bas recharge la liste', (tester) async {
    final repo = FakeMatchRepository(upcoming: [fakeMatch()]);
    await tester.pumpWidget(
      _wrap(MatchListScreen(matches: repo, profileButton: const SizedBox())),
    );
    await tester.pumpAndSettle();

    repo.upcoming = [fakeMatch(), fakeMatch(id: 'm2', title: 'Nouveau match')];
    await tester.fling(
      find.text('Foot du dimanche'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouveau match'), findsOneWidget);
  });

  group('détail', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      FakeMatchRepository repo,
    ) async {
      await tester.pumpWidget(
        _wrap(MatchDetailScreen(matchId: 'm1', matches: repo)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('un joueur ne voit pas les actions de l\'organisateur', (
      tester,
    ) async {
      await pumpDetail(tester, FakeMatchRepository(upcoming: [fakeMatch()]));
      expect(find.text('Modifier'), findsNothing);
      expect(find.text('Annuler le match'), findsNothing);
    });

    testWidgets('coût estimé par joueur affiché comme indicatif', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeMatchRepository(upcoming: [fakeMatch(estimatedCostPerPlayer: 5.5)]),
      );
      expect(
        find.textContaining('Coût estimé par joueur : 5,50'),
        findsOneWidget,
      );
      expect(find.textContaining('indicatif'), findsOneWidget);
    });

    testWidgets('l\'organisateur annule après confirmation', (tester) async {
      final repo = FakeMatchRepository(
        upcoming: [fakeMatch(isOrganizer: true)],
      );
      await pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Annuler le match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Annuler le match'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Annuler le match'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['cancel:m1']);
    });

    testWidgets('pas d\'action sur un match annulé', (tester) async {
      await pumpDetail(
        tester,
        FakeMatchRepository(
          upcoming: [
            fakeMatch(
              isOrganizer: true,
              displayStatus: MatchDisplayStatus.cancelled,
            ),
          ],
        ),
      );
      expect(find.text('Annulé'), findsOneWidget);
      expect(find.text('Modifier'), findsNothing);
      expect(find.textContaining('libre'), findsNothing);
    });
  });

  group('formulaire', () {
    Future<void> pumpForm(
      WidgetTester tester,
      FakeMatchRepository repo, {
      Match? initial,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          MatchFormScreen(matches: repo, initial: initial, now: () => _now),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickTomorrowAt18(WidgetTester tester) async {
      await tester.tap(find.text('Date et heure de début'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('29'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // heure par défaut : 18:00
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('création d\'un match au lieu à définir', (tester) async {
      final repo = FakeMatchRepository();
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot entre voisins');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['create']);
      final input = repo.inputs.single;
      expect(input.title, 'Foot entre voisins');
      expect(input.startsAt, DateTime(2026, 10, 29, 18));
      expect(input.capacity, 10);
      expect(input.locationMode, LocationMode.toDefine);
      expect(input.toJson()['latitude'], isNull);
    });

    testWidgets('le format propose une capacité adaptée', (tester) async {
      await pumpForm(tester, FakeMatchRepository());
      await tester.tap(find.text('7v7'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '14'), findsOneWidget);
    });

    testWidgets('date obligatoire et capacité minimale 4', (tester) async {
      final repo = FakeMatchRepository();
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot');
      await tester.enterText(field('Nombre total de joueurs'), '3');
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(find.text('Minimum 4 joueurs.'), findsOneWidget);
      expect(find.textContaining('Choisissez la date'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('un terrain précis exige un nom et une position', (
      tester,
    ) async {
      final repo = FakeMatchRepository();
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Terrain précis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(find.text('Indiquez le nom du terrain.'), findsOneWidget);
      expect(find.text('Obligatoire.'), findsNWidgets(2));
      expect(repo.calls, isEmpty);
    });

    testWidgets('une erreur serveur est affichée', (tester) async {
      final repo = FakeMatchRepository()
        ..createError = const AppError(
          'START_TOO_SOON',
          'Le match doit commencer dans au moins 15 minutes.',
        );
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(
        find.text('Le match doit commencer dans au moins 15 minutes.'),
        findsOneWidget,
      );
    });

    testWidgets('modification : capacité inférieure aux inscrits refusée', (
      tester,
    ) async {
      final repo = FakeMatchRepository();
      await pumpForm(
        tester,
        repo,
        initial: fakeMatch(isOrganizer: true, participantCount: 6),
      );

      await tester.enterText(field('Nombre total de joueurs'), '5');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('6 personnes sont déjà inscrites.'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.enterText(field('Nombre total de joueurs'), '8');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['update:m1']);
      expect(repo.inputs.single.capacity, 8);
    });
  });
}
