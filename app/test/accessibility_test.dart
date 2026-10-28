import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x5football/data/app_error.dart';
import 'package:x5football/features/auth/sign_in_screen.dart';
import 'package:x5football/features/matches/match_detail_screen.dart';
import 'package:x5football/features/matches/match_form_screen.dart';
import 'package:x5football/features/matches/match_list_screen.dart';
import 'package:x5football/features/moderation/blocked_users_screen.dart';
import 'package:x5football/features/notifications/notifications_screen.dart';
import 'package:x5football/features/profile/profile_screen.dart';
import 'package:x5football/models/app_notification.dart';
import 'package:x5football/models/match.dart';
import 'package:x5football/models/moderation.dart';
import 'package:x5football/models/profile.dart';
import 'package:x5football/ui/image_pick.dart';
import 'package:x5football/ui/states.dart';
import 'package:x5football/ui/theme.dart';

import 'fakes.dart';

const _participants = [
  Participant(userId: 'orga', displayName: 'Orga', isOrganizer: true),
  Participant(userId: 'alice', displayName: 'Alice', isOrganizer: false),
];

Widget _app(
  Widget home, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => MaterialApp(
  locale: const Locale('fr', 'FR'),
  supportedLocales: const [Locale('fr', 'FR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

/// Écrans principaux, dans un état représentatif.
final Map<String, Widget Function()> _screens = {
  'connexion': () => SignInScreen(auth: FakeAuthRepository()),
  'mes matchs': () => MatchListScreen(
    matches: FakeMatchRepository(
      mine: [
        fakeMatch(isOrganizer: true),
        fakeMatch(
          id: 'm2',
          title: 'Match complet du samedi soir avec un titre long',
          capacity: 10,
          participantCount: 10,
          displayStatus: MatchDisplayStatus.full,
          isParticipant: true,
        ),
        fakeMatch(id: 'm3', displayStatus: MatchDisplayStatus.cancelled),
      ],
    ),
    geocoding: FakeGeocodingRepository(),
    location: FakeLocationService(),
    notifications: FakeNotificationRepository(),
    moderation: FakeModerationRepository(),
    profileButton: const SizedBox(),
  ),
  'détail joueur': () => MatchDetailScreen(
    matchId: 'm1',
    moderation: FakeModerationRepository(),
    matches: FakeMatchRepository(
      nearby: [fakeMatch(isParticipant: true, estimatedCostPerPlayer: 5)],
      participants: _participants,
    )..transfer = fakeTransfer(),
    geocoding: FakeGeocodingRepository(),
    location: FakeLocationService(),
  ),
  'détail organisateur': () => MatchDetailScreen(
    matchId: 'm1',
    moderation: FakeModerationRepository(),
    matches: FakeMatchRepository(
      nearby: [fakeMatch(isOrganizer: true)],
      participants: _participants,
    ),
    geocoding: FakeGeocodingRepository(),
    location: FakeLocationService(),
  ),
  'formulaire': () => MatchFormScreen(
    matches: FakeMatchRepository(),
    geocoding: FakeGeocodingRepository(),
    location: FakeLocationService(),
  ),
  'notifications': () => NotificationsScreen(
    notifications: FakeNotificationRepository(
      items: [
        AppNotification(
          id: 'n1',
          type: 'match_reminder',
          title: 'Rappel : votre match approche',
          body: '« Foot du dimanche » commence dans 24 h — City stade.',
          date: DateTime(2026, 10, 28, 12),
          isRead: false,
          matchId: 'm1',
        ),
      ],
    ),
    onOpenMatch: (_) {},
  ),
  'joueurs bloqués': () => BlockedUsersScreen(
    moderation: FakeModerationRepository(
      blocked: const [BlockedUser(userId: 'b', displayName: 'Bruno')],
    ),
  ),
  'profil': () => ProfileScreen(
    moderation: FakeModerationRepository(),
    profile: const Profile(id: 'me', displayName: 'Nabil'),
    profiles: FakeProfileRepository(
      profile: const Profile(id: 'me', displayName: 'Nabil'),
    ),
    auth: FakeAuthRepository(signedIn: true),
    onProfileChanged: (_) {},
  ),
};

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  for (final brightness in Brightness.values) {
    group('accessibilité (${brightness.name})', () {
      for (final entry in _screens.entries) {
        testWidgets(entry.key, (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(_app(entry.value(), brightness: brightness));
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    });
  }

  group('texte agrandi à 200 %', () {
    for (final entry in _screens.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(entry.value(), textScale: 2));
        await tester.pumpAndSettle();
        // Un débordement de mise en page est signalé comme exception.
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: error is FlutterError ? error.toStringDeep() : '$error',
        );
      });
    }
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('à proximité avec filtres, texte ×$textScale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          MatchListScreen(
            matches: FakeMatchRepository(nearby: [fakeMatch()]),
            geocoding: FakeGeocodingRepository(),
            location: FakeLocationService(),
            notifications: FakeNotificationRepository(),
            moderation: FakeModerationRepository(),
            profileButton: const SizedBox(),
          ),
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autour de moi'));
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isNull, reason: '$error');
      expect(find.text('Rayon 10 km'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  group('lecteurs d\'écran', () {
    testWidgets('une fiche de match est annoncée d\'un seul tenant', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_screens['mes matchs']!()));
      await tester.tap(find.text('Mes matchs'));
      await tester.pumpAndSettle();

      // Le texte fait partie d'un nœud fusionné : c'est ce nœud qui est renvoyé.
      final node = tester.getSemantics(
        find.text('Match complet du samedi soir avec un titre long'),
      );
      final data = node.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains('Match complet du samedi soir'));
      expect(data.label, contains('Complet'));
      expect(data.label, contains('Inscrit'));
      expect(data.label, contains('5 contre 5'));
      handle.dispose();
    });

    testWidgets('le titre du match est un en-tête', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_screens['détail organisateur']!()));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Foot du dimanche')),
        matchesSemantics(label: 'Foot du dimanche', isHeader: true),
      );
      handle.dispose();
    });
  });

  group('hors ligne', () {
    test('une coupure réseau donne un message dédié', () {
      final error = AppError.from(const SocketException('Failed host lookup'));
      expect(error.isOffline, isTrue);
      expect(error.message, contains('hors ligne'));
    });

    testWidgets('écran d\'erreur hors ligne avec « Réessayer »', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: MessageView.error(
              const AppError(AppError.offlineCode, AppError.offlineMessage),
              onRetry: () => retried++,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(retried, 1);
    });
  });

  group('photo de profil', () {
    Future<FakeProfileRepository> pumpProfile(
      WidgetTester tester, {
      PickedImage? picked,
      String? avatarUrl,
    }) async {
      final profile = Profile(
        id: 'me',
        displayName: 'Nabil',
        avatarUrl: avatarUrl,
      );
      final profiles = FakeProfileRepository(profile: profile);
      await tester.pumpWidget(
        _app(
          ProfileScreen(
            moderation: FakeModerationRepository(),
            profile: profile,
            profiles: profiles,
            auth: FakeAuthRepository(signedIn: true),
            onProfileChanged: (_) {},
            pickImage: (_) async => picked,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return profiles;
    }

    testWidgets('ajouter une photo depuis la galerie', (tester) async {
      final profiles = await pumpProfile(
        tester,
        picked: PickedImage(Uint8List(2048), 'jpg'),
      );
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();

      expect(profiles.calls, ['avatar:2048:jpg']);
      expect(find.text('Changer la photo'), findsOneWidget);
    });

    testWidgets('annuler la sélection ne change rien', (tester) async {
      final profiles = await pumpProfile(tester);
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prendre une photo'));
      await tester.pumpAndSettle();
      expect(profiles.calls, isEmpty);
    });

    testWidgets('retirer la photo', (tester) async {
      final profiles = await pumpProfile(tester, avatarUrl: 'me/avatar-1.jpg');
      await tester.tap(find.text('Changer la photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer la photo'));
      await tester.pumpAndSettle();
      expect(profiles.calls, ['removeAvatar']);
      expect(find.text('Photo retirée.'), findsOneWidget);
    });
  });
}
