import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:x5football/features/matches/match_detail_screen.dart';
import 'package:x5football/features/matches/match_list_screen.dart';
import 'package:x5football/models/app_notification.dart';
import 'package:x5football/models/match.dart';

import 'fakes.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('fr', 'FR'),
  supportedLocales: const [Locale('fr', 'FR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

const _participants = [
  Participant(userId: 'orga', displayName: 'Orga', isOrganizer: true),
  Participant(userId: 'alice', displayName: 'Alice', isOrganizer: false),
];

AppNotification _notification({
  String id = 'n1',
  String title = 'Proposition d\'organisation',
  String? matchId = 'm1',
  bool isRead = false,
}) => AppNotification(
  id: id,
  type: 'transfer_proposed',
  title: title,
  body: 'Orga vous propose d\'organiser « Foot du dimanche ».',
  matchId: matchId,
  date: DateTime(2026, 10, 28, 12),
  isRead: isRead,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pumpDetail(WidgetTester tester, FakeMatchRepository repo) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        MatchDetailScreen(
          matchId: 'm1',
          matches: repo,
          geocoding: FakeGeocodingRepository(),
          location: FakeLocationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('transfert d\'organisation', () {
    testWidgets('l\'organisateur choisit un participant puis confirme', (
      tester,
    ) async {
      final repo = FakeMatchRepository(
        nearby: [fakeMatch(isOrganizer: true)],
        participants: _participants,
      );
      await pumpDetail(tester, repo);

      await tester.tap(find.text('Transmettre l\'organisation'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SimpleDialogOption, 'Orga'), findsNothing);
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Alice'));
      await tester.pumpAndSettle();
      expect(find.textContaining('48 h'), findsOneWidget);

      await tester.tap(find.text('Envoyer la proposition'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['propose:m1:alice']);
      expect(find.text('Proposition envoyée à Alice.'), findsOneWidget);
    });

    testWidgets('pas de transfert possible sans autre participant', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeMatchRepository(
          nearby: [fakeMatch(isOrganizer: true)],
          participants: _participants.take(1).toList(),
        ),
      );
      expect(find.text('Transmettre l\'organisation'), findsNothing);
    });

    testWidgets('l\'organisateur voit sa proposition et peut la retirer', (
      tester,
    ) async {
      final repo = FakeMatchRepository(
        nearby: [fakeMatch(isOrganizer: true)],
        participants: _participants,
      )..transfer = fakeTransfer();
      await pumpDetail(tester, repo);

      expect(find.text('Proposition envoyée à Alice'), findsOneWidget);
      expect(find.text('Transmettre l\'organisation'), findsNothing);
      await tester.tap(find.text('Retirer la proposition'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['cancelTransfer:m1']);
    });

    testWidgets('le participant ciblé accepte', (tester) async {
      final repo = FakeMatchRepository(
        nearby: [fakeMatch(isParticipant: true)],
        participants: _participants,
      )..transfer = fakeTransfer();
      await pumpDetail(tester, repo);

      expect(
        find.text('Orga vous propose d\'organiser ce match'),
        findsOneWidget,
      );
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['respond:t1:true']);
      expect(find.text('Vous organisez désormais ce match.'), findsOneWidget);
    });

    testWidgets('le participant ciblé refuse', (tester) async {
      final repo = FakeMatchRepository(
        nearby: [fakeMatch(isParticipant: true)],
        participants: _participants,
      )..transfer = fakeTransfer();
      await pumpDetail(tester, repo);

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['respond:t1:false']);
    });

    testWidgets('aucune action de transfert sur un match annulé', (
      tester,
    ) async {
      final repo = FakeMatchRepository(
        nearby: [
          fakeMatch(
            isOrganizer: true,
            displayStatus: MatchDisplayStatus.cancelled,
          ),
        ],
        participants: _participants,
      );
      await pumpDetail(tester, repo);
      expect(find.text('Transmettre l\'organisation'), findsNothing);
    });
  });

  group('notifications', () {
    Future<FakeNotificationRepository> pumpHome(
      WidgetTester tester,
      List<AppNotification> items,
    ) async {
      final notifications = FakeNotificationRepository(items: items);
      await tester.pumpWidget(
        _wrap(
          MatchListScreen(
            matches: FakeMatchRepository(
              nearby: [fakeMatch()],
              participants: _participants,
            ),
            geocoding: FakeGeocodingRepository(),
            location: FakeLocationService(),
            notifications: notifications,
            profileButton: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return notifications;
    }

    testWidgets('la pastille affiche le nombre de non-lues', (tester) async {
      await pumpHome(tester, [
        _notification(),
        _notification(id: 'n2'),
        _notification(id: 'n3', isRead: true),
      ]);
      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('Notifications, 2 non lues'), findsOneWidget);
    });

    testWidgets('ouvrir la liste marque tout comme lu', (tester) async {
      final notifications = await pumpHome(tester, [_notification()]);

      await tester.tap(find.byTooltip('Notifications, 1 non lue'));
      await tester.pumpAndSettle();
      expect(find.text('Proposition d\'organisation'), findsOneWidget);
      expect(notifications.markAllReadCalls, 1);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('toucher une notification ouvre le match', (tester) async {
      await pumpHome(tester, [_notification()]);
      await tester.tap(find.byTooltip('Notifications, 1 non lue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Proposition d\'organisation'));
      await tester.pumpAndSettle();
      expect(find.text('Foot du dimanche'), findsOneWidget);
      expect(find.text('Participants'), findsOneWidget);
    });

    testWidgets('liste vide', (tester) async {
      await pumpHome(tester, []);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune notification.'), findsOneWidget);
    });
  });
}
