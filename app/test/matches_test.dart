import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x5football/data/app_error.dart';
import 'package:x5football/data/match_repository.dart';
import 'package:x5football/features/matches/match_detail_screen.dart';
import 'package:x5football/features/matches/match_form_screen.dart';
import 'package:x5football/features/matches/match_list_screen.dart';
import 'package:x5football/models/geo.dart';
import 'package:x5football/models/match.dart';
import 'package:x5football/ui/formatters.dart';
import 'package:x5football/ui/maps_launcher.dart';

import 'fakes.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('fr', 'FR'),
  supportedLocales: const [Locale('fr', 'FR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

final _now = DateTime(2026, 10, 28, 10);

const _stadeJeanBouin = Place(
  name: 'Stade Jean-Bouin',
  label: 'Stade Jean-Bouin, Avenue du Général Sarrail, Paris, France',
  point: GeoPoint(48.8433, 2.2530),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('géographie', () {
    test('distance à vol d\'oiseau', () {
      const paris = GeoPoint(48.8566, 2.3522);
      const lyon = GeoPoint(45.7640, 4.8357);
      expect(paris.distanceKmTo(lyon), closeTo(392, 2));
      expect(paris.distanceKmTo(paris), 0);
    });

    test('affichage des distances', () {
      expect(formatDistance(0.01), '50 m');
      expect(formatDistance(0.84), '850 m');
      expect(formatDistance(0.99), '1,0 km');
      expect(formatDistance(2.44), '2,4 km');
      expect(formatDistance(12.6), '13 km');
    });

    test('lien Google Maps universel, sans clé', () {
      expect(
        mapsUri(const GeoPoint(48.8433, 2.253)).toString(),
        'https://www.google.com/maps/search/?api=1&query=48.8433%2C2.253',
      );
    });

    test('paramètres de recherche envoyés au serveur', () {
      final search = MatchSearch(
        center: const GeoPoint(-22.91, -43.23),
        radiusKm: 25,
        availableOnly: true,
        skillLevel: SkillLevel.beginner,
      );
      expect(search.toParams(), {
        'p_latitude': -22.91,
        'p_longitude': -43.23,
        'p_radius_km': 25,
        'p_available_only': true,
        'p_skill_level': 'beginner',
        'p_starts_before': null,
        'p_limit': 20,
        'p_offset': 0,
      });
      expect(search.nextPage().toParams()['p_offset'], 20);
      expect(
        const MatchSearch(center: GeoPoint(0, 0)).radiusKm,
        10,
        reason: 'rayon par défaut de 10 km',
      );
    });
  });

  test('MatchInput envoie toujours le terrain et une date UTC', () {
    final json = MatchInput(
      title: 'Foot',
      startsAt: DateTime.utc(2026, 11, 1, 14),
      durationMinutes: 90,
      capacity: 10,
      format: MatchFormat.fiveASide,
      skillLevel: SkillLevel.all,
      locationName: 'Stade',
      location: const GeoPoint(47.39, 0.69),
    ).toJson();
    expect(json['location_name'], 'Stade');
    expect(json['latitude'], 47.39);
    expect(json['longitude'], 0.69);
    expect(json.containsKey('location_mode'), isFalse);
    expect(json['starts_at'], '2026-11-01T14:00:00.000Z');
  });

  group('à proximité', () {
    late FakeMatchRepository repo;
    late FakeLocationService location;
    late FakeGeocodingRepository geocoding;

    setUp(() {
      repo = FakeMatchRepository();
      location = FakeLocationService();
      geocoding = FakeGeocodingRepository(places: [_stadeJeanBouin]);
    });

    Future<void> pumpList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          MatchListScreen(
            matches: repo,
            geocoding: geocoding,
            location: location,
            profileButton: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('rien n\'est demandé avant le choix de l\'utilisateur', (
      tester,
    ) async {
      await pumpList(tester);
      expect(location.calls, 0);
      expect(repo.searches, isEmpty);
      expect(find.textContaining('Utilisez votre position'), findsOneWidget);
    });

    testWidgets('autour de moi : rayon de 10 km et distance affichée', (
      tester,
    ) async {
      repo.nearby = [
        fakeMatch(participantCount: 3, latitude: 47.41, longitude: 0.69),
      ];
      await pumpList(tester);

      await tester.tap(find.text('Autour de moi'));
      await tester.pumpAndSettle();

      expect(repo.searches.single.center, const GeoPoint(47.39, 0.69));
      expect(repo.searches.single.radiusKm, 10);
      expect(find.text('Autour de ma position'), findsOneWidget);
      expect(find.textContaining('2,2 km · City stade des Rives'), findsOne);
      expect(find.text('7 places restantes'), findsOneWidget);
    });

    testWidgets('GPS refusé : message et recherche par ville possible', (
      tester,
    ) async {
      location.error = const AppError(
        'LOCATION_DENIED',
        'Accès à la position refusé. Recherchez plutôt une ville ou une adresse.',
      );
      await pumpList(tester);

      await tester.tap(find.text('Autour de moi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Accès à la position refusé'), findsOneWidget);
      expect(repo.searches, isEmpty);

      await tester.tap(find.text('Choisir une ville ou une adresse'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Jean Bouin Paris');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(geocoding.queries, ['Jean Bouin Paris']);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);

      await tester.tap(find.text('Stade Jean-Bouin'));
      await tester.pumpAndSettle();
      expect(repo.searches.single.center, _stadeJeanBouin.point);
      expect(find.text('Autour de Stade Jean-Bouin'), findsOneWidget);
      expect(
        find.textContaining('Aucun match dans un rayon de 10 km'),
        findsOne,
      );
    });

    testWidgets('changer le rayon ou un filtre relance la recherche', (
      tester,
    ) async {
      await pumpList(tester);
      await tester.tap(find.text('Autour de moi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rayon 10 km'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rayon 25 km').last);
      await tester.pumpAndSettle();
      expect(repo.searches.last.radiusKm, 25);

      await tester.tap(find.text('Places disponibles'));
      await tester.pumpAndSettle();
      expect(repo.searches.last.availableOnly, isTrue);
      expect(repo.searches.last.radiusKm, 25);
    });

    testWidgets('pagination : afficher plus de matchs', (tester) async {
      repo.nearby = [
        for (var i = 0; i < 25; i++) fakeMatch(id: 'm$i', title: 'Match $i'),
      ];
      await pumpList(tester);
      await tester.tap(find.text('Autour de moi'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Afficher plus de matchs'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      // Fin de liste : le bouton n'est plus sous le bouton « Créer un match ».
      await tester.drag(
        find.text('Afficher plus de matchs'),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Afficher plus de matchs'));
      await tester.pumpAndSettle();

      expect(repo.searches.last.offset, 20);
      expect(find.text('Afficher plus de matchs'), findsNothing);
    });
  });

  testWidgets('mes matchs : tirer vers le bas recharge la liste', (
    tester,
  ) async {
    final repo = FakeMatchRepository(mine: [fakeMatch(isParticipant: true)]);
    await tester.pumpWidget(
      _wrap(
        MatchListScreen(
          matches: repo,
          geocoding: FakeGeocodingRepository(),
          location: FakeLocationService(),
          profileButton: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.text('Mes matchs'));
    await tester.pumpAndSettle();

    repo.mine = [fakeMatch(), fakeMatch(id: 'm2', title: 'Nouveau match')];
    await tester.fling(
      find.text('Foot du dimanche'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouveau match'), findsOneWidget);
  });

  group('détail', () {
    final opened = <Uri>[];
    var openSucceeds = true;

    Future<void> pumpDetail(
      WidgetTester tester,
      FakeMatchRepository repo,
    ) async {
      opened.clear();
      await tester.pumpWidget(
        _wrap(
          MatchDetailScreen(
            matchId: 'm1',
            matches: repo,
            geocoding: FakeGeocodingRepository(),
            location: FakeLocationService(),
            openUrl: (uri) async {
              opened.add(uri);
              return openSucceeds;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('un joueur ne voit pas les actions de l\'organisateur', (
      tester,
    ) async {
      await pumpDetail(tester, FakeMatchRepository(nearby: [fakeMatch()]));
      expect(find.text('City stade des Rives'), findsOneWidget);
      expect(find.text('Modifier'), findsNothing);
      expect(find.text('Annuler le match'), findsNothing);
    });

    testWidgets('ouvrir le terrain dans Google Maps', (tester) async {
      openSucceeds = true;
      await pumpDetail(tester, FakeMatchRepository(nearby: [fakeMatch()]));
      await tester.tap(find.text('Ouvrir dans Maps'));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'www.google.com');
      expect(opened.single.queryParameters['query'], '47.39,0.69');
    });

    testWidgets('échec d\'ouverture de Maps signalé', (tester) async {
      openSucceeds = false;
      await pumpDetail(tester, FakeMatchRepository(nearby: [fakeMatch()]));
      await tester.tap(find.text('Ouvrir dans Maps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Impossible d\'ouvrir'), findsOneWidget);
    });

    testWidgets('coût estimé par joueur affiché comme indicatif', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeMatchRepository(nearby: [fakeMatch(estimatedCostPerPlayer: 5.5)]),
      );
      expect(
        find.textContaining('Coût estimé par joueur : 5,50'),
        findsOneWidget,
      );
      expect(find.textContaining('indicatif'), findsOneWidget);
    });

    testWidgets('l\'organisateur annule après confirmation', (tester) async {
      final repo = FakeMatchRepository(nearby: [fakeMatch(isOrganizer: true)]);
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
          nearby: [
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
      expect(find.text('Rejoindre le match'), findsNothing);
    });

    group('inscription', () {
      testWidgets('rejoindre un match ouvert', (tester) async {
        final repo = FakeMatchRepository(nearby: [fakeMatch()]);
        await pumpDetail(tester, repo);

        await tester.tap(find.text('Rejoindre le match'));
        await tester.pumpAndSettle();

        expect(repo.calls, ['join:m1']);
        expect(find.text('Vous êtes inscrit. Bon match !'), findsOneWidget);
      });

      testWidgets('refus du serveur affiché (dernière place prise)', (
        tester,
      ) async {
        final repo = FakeMatchRepository(nearby: [fakeMatch()])
          ..participationError = const AppError(
            'MATCH_FULL',
            'Ce match est complet.',
          );
        await pumpDetail(tester, repo);

        await tester.tap(find.text('Rejoindre le match'));
        await tester.pumpAndSettle();
        expect(find.text('Ce match est complet.'), findsOneWidget);
      });

      testWidgets('match complet : inscription impossible', (tester) async {
        await pumpDetail(
          tester,
          FakeMatchRepository(
            nearby: [
              fakeMatch(
                capacity: 10,
                participantCount: 10,
                displayStatus: MatchDisplayStatus.full,
              ),
            ],
          ),
        );
        final button = find.widgetWithText(FilledButton, 'Match complet');
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(find.text('Rejoindre le match'), findsNothing);
      });

      testWidgets('quitter un match après confirmation', (tester) async {
        final repo = FakeMatchRepository(
          nearby: [fakeMatch(isParticipant: true)],
        );
        await pumpDetail(tester, repo);
        expect(find.text('Vous êtes inscrit à ce match.'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Quitter le match'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rester inscrit'));
        await tester.pumpAndSettle();
        expect(repo.calls, isEmpty);

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Quitter le match'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Quitter le match'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['leave:m1']);
        expect(find.text('Vous avez quitté le match.'), findsOneWidget);
      });

      testWidgets('l\'organisateur ne peut ni rejoindre ni quitter', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          FakeMatchRepository(nearby: [fakeMatch(isOrganizer: true)]),
        );
        expect(find.text('Rejoindre le match'), findsNothing);
        expect(find.text('Quitter le match'), findsNothing);
      });
    });
  });

  group('formulaire', () {
    late FakeLocationService location;
    late FakeGeocodingRepository geocoding;

    Future<void> pumpForm(
      WidgetTester tester,
      FakeMatchRepository repo, {
      Match? initial,
    }) async {
      location = FakeLocationService();
      geocoding = FakeGeocodingRepository(places: [_stadeJeanBouin]);
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          MatchFormScreen(
            matches: repo,
            geocoding: geocoding,
            location: location,
            initial: initial,
            now: () => _now,
          ),
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

    testWidgets('création avec recherche d\'adresse : nom proposé', (
      tester,
    ) async {
      final repo = FakeMatchRepository();
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot entre voisins');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Rechercher l\'adresse'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Jean Bouin');
      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stade Jean-Bouin'));
      await tester.pumpAndSettle();

      expect(find.text(_stadeJeanBouin.label), findsOneWidget);
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['create']);
      final input = repo.inputs.single;
      expect(input.title, 'Foot entre voisins');
      expect(input.startsAt, DateTime(2026, 10, 29, 18));
      expect(input.capacity, 10);
      expect(input.locationName, 'Stade Jean-Bouin');
      expect(input.location, _stadeJeanBouin.point);
    });

    testWidgets('position actuelle du téléphone comme terrain', (tester) async {
      final repo = FakeMatchRepository();
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot');
      await tester.enterText(field('Nom du terrain'), 'Parc des Prébendes');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Ma position actuelle'));
      await tester.pumpAndSettle();
      expect(find.text('Position actuelle du téléphone'), findsOneWidget);

      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();
      expect(repo.inputs.single.locationName, 'Parc des Prébendes');
      expect(repo.inputs.single.location, location.position);
    });

    testWidgets('le terrain (nom et position) est obligatoire', (tester) async {
      final repo = FakeMatchRepository();
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(find.text('Indiquez le nom du terrain.'), findsOneWidget);
      expect(find.text('Choisissez la position du terrain.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('position refusée : message affiché', (tester) async {
      await pumpForm(tester, FakeMatchRepository());
      location.error = const AppError('LOCATION_DENIED', 'Accès refusé.');
      await tester.tap(find.text('Ma position actuelle'));
      await tester.pumpAndSettle();
      expect(find.text('Accès refusé.'), findsOneWidget);
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

    testWidgets('une erreur serveur est affichée', (tester) async {
      final repo = FakeMatchRepository()
        ..createError = const AppError(
          'START_TOO_SOON',
          'Le match doit commencer dans au moins 15 minutes.',
        );
      await pumpForm(tester, repo);

      await tester.enterText(field('Titre'), 'Foot');
      await tester.enterText(field('Nom du terrain'), 'City stade');
      await pickTomorrowAt18(tester);
      await tester.tap(find.text('Ma position actuelle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer le match'));
      await tester.pumpAndSettle();

      expect(
        find.text('Le match doit commencer dans au moins 15 minutes.'),
        findsOneWidget,
      );
    });

    testWidgets('modification : terrain conservé, capacité contrôlée', (
      tester,
    ) async {
      final repo = FakeMatchRepository();
      await pumpForm(
        tester,
        repo,
        initial: fakeMatch(isOrganizer: true, participantCount: 6),
      );
      expect(find.text('Position enregistrée'), findsOneWidget);

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
      expect(repo.inputs.single.location, const GeoPoint(47.39, 0.69));
      expect(repo.inputs.single.locationName, 'City stade des Rives');
    });
  });
}
