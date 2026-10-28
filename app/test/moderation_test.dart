import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x5football/data/app_error.dart';
import 'package:x5football/features/matches/match_detail_screen.dart';
import 'package:x5football/features/moderation/blocked_users_screen.dart';
import 'package:x5football/models/match.dart';
import 'package:x5football/models/moderation.dart';
import 'package:x5football/ui/theme.dart';

import 'fakes.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('fr', 'FR'),
  supportedLocales: const [Locale('fr', 'FR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildTheme(Brightness.light),
  home: home,
);

const _participants = [
  Participant(userId: 'orga', displayName: 'Orga', isOrganizer: true),
  Participant(
    userId: 'me',
    displayName: 'Nabil',
    isOrganizer: false,
    isMe: true,
  ),
  Participant(userId: 'bruno', displayName: 'Bruno', isOrganizer: false),
];

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<FakeModerationRepository> pumpDetail(
    WidgetTester tester, {
    bool isOrganizer = false,
    FakeModerationRepository? moderation,
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = moderation ?? FakeModerationRepository();
    await tester.pumpWidget(
      _app(
        MatchDetailScreen(
          matchId: 'm1',
          matches: FakeMatchRepository(
            nearby: [fakeMatch(isOrganizer: isOrganizer, isParticipant: true)],
            participants: _participants,
          ),
          geocoding: FakeGeocodingRepository(),
          location: FakeLocationService(),
          moderation: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('signaler', () {
    testWidgets('signaler un match avec un motif et un commentaire', (
      tester,
    ) async {
      final repo = await pumpDetail(tester);

      await tester.tap(find.byTooltip('Plus d\'options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler ce match'));
      await tester.pumpAndSettle();

      final send = find.widgetWithText(FilledButton, 'Envoyer le signalement');
      expect(
        tester.widget<FilledButton>(send).onPressed,
        isNull,
        reason: 'motif obligatoire',
      );

      await tester.tap(find.text(ReportReason.fakeMatch.label));
      await tester.enterText(find.byType(TextField), '  Terrain inexistant ');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(repo.calls, ['report:fake_match:m1:Terrain inexistant']);
      expect(find.textContaining('sera examiné'), findsOneWidget);
    });

    testWidgets('l\'organisateur ne peut pas signaler son propre match', (
      tester,
    ) async {
      await pumpDetail(tester, isOrganizer: true);
      expect(find.byTooltip('Plus d\'options'), findsNothing);
    });

    testWidgets('signaler un joueur depuis la liste des participants', (
      tester,
    ) async {
      final repo = await pumpDetail(tester);
      await tester.tap(find.byTooltip('Options pour Bruno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      expect(find.text('Signaler Bruno'), findsOneWidget);

      await tester.tap(find.text(ReportReason.harassment.label));
      await tester.pump();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['report:harassment:bruno:']);
    });

    testWidgets('pas d\'options sur sa propre ligne', (tester) async {
      await pumpDetail(tester);
      expect(find.byTooltip('Options pour Nabil'), findsNothing);
      expect(find.byTooltip('Options pour Orga'), findsOneWidget);
    });

    testWidgets('limite atteinte : message affiché, formulaire conservé', (
      tester,
    ) async {
      final repo = FakeModerationRepository()
        ..reportError = const AppError(
          'RATE_LIMITED',
          'Vous avez atteint la limite de 10 signalements par jour.',
        );
      await pumpDetail(tester, moderation: repo);
      await tester.tap(find.byTooltip('Options pour Bruno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ReportReason.spam.label));
      await tester.pump();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('limite de 10 signalements'), findsOneWidget);
      expect(find.text('Envoyer le signalement'), findsOneWidget);
    });
  });

  group('bloquer', () {
    testWidgets('bloquer un joueur après confirmation', (tester) async {
      final repo = await pumpDetail(tester);
      await tester.tap(find.byTooltip('Options pour Bruno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Il n\'en sera pas informé'), findsOneWidget);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.byTooltip('Options pour Bruno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloquer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Bloquer'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['block:bruno']);
      expect(find.text('Bruno est bloqué.'), findsOneWidget);
    });

    testWidgets('liste des joueurs bloqués et déblocage', (tester) async {
      final repo = FakeModerationRepository(
        blocked: const [BlockedUser(userId: 'bruno', displayName: 'Bruno')],
      );
      await tester.pumpWidget(_app(BlockedUsersScreen(moderation: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Bruno'), findsOneWidget);
      await tester.tap(find.text('Débloquer'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['unblock:bruno']);
      expect(find.text('Vous n\'avez bloqué personne.'), findsOneWidget);
    });
  });
}
