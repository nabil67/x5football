import 'dart:async';
import 'dart:typed_data';

import 'package:x5football/data/app_error.dart';
import 'package:x5football/data/auth_repository.dart';
import 'package:x5football/data/geocoding_repository.dart';
import 'package:x5football/data/location_service.dart';
import 'package:x5football/data/match_repository.dart';
import 'package:x5football/data/notification_repository.dart';
import 'package:x5football/models/app_notification.dart';
import 'package:x5football/data/profile_repository.dart';
import 'package:x5football/models/geo.dart';
import 'package:x5football/models/match.dart';
import 'package:x5football/models/profile.dart';
import 'package:x5football/models/transfer.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = false});

  final _changes = StreamController<bool>.broadcast();
  bool signedIn;
  final calls = <String>[];

  /// Erreur levée par la prochaine vérification de code, le cas échéant.
  AppError? verifyError;

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  void _set(bool value) {
    signedIn = value;
    _changes.add(value);
  }

  @override
  Future<void> sendEmailCode(String email) async => calls.add('send:$email');

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    calls.add('verify:$email:$code');
    if (verifyError != null) throw verifyError!;
    _set(true);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _set(false);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});

  Profile? profile;
  final calls = <String>[];
  AppError? completeError;

  @override
  Future<Profile?> fetchMyProfile() async => profile;

  @override
  Future<Profile> completeProfile({
    required String displayName,
    required bool isAdult,
  }) async {
    calls.add('complete:$displayName:$isAdult');
    if (completeError != null) throw completeError!;
    return profile = Profile(id: 'me', displayName: displayName);
  }

  @override
  Future<Profile> updateDisplayName(String displayName) async {
    calls.add('update:$displayName');
    return profile = Profile(id: 'me', displayName: displayName);
  }

  @override
  Future<Profile> updateAvatar(
    Uint8List bytes, {
    required String extension,
  }) async {
    calls.add('avatar:${bytes.length}:$extension');
    return profile = Profile(
      id: 'me',
      displayName: profile!.displayName,
      avatarUrl: 'me/avatar-1.$extension',
    );
  }

  @override
  Future<Profile> removeAvatar() async {
    calls.add('removeAvatar');
    return profile = Profile(id: 'me', displayName: profile!.displayName);
  }

  @override
  Future<void> requestAccountDeletion() async => calls.add('delete');
}

class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository({
    List<Match>? nearby,
    List<Match>? mine,
    this.participants = const [],
  }) : nearby = nearby ?? [],
       mine = mine ?? [];

  /// Résultats renvoyés par la recherche (découpés selon limit / offset).
  List<Match> nearby;
  final searches = <MatchSearch>[];
  List<Match> mine;
  List<Participant> participants;
  final calls = <String>[];
  final inputs = <MatchInput>[];
  AppError? createError;

  @override
  Future<List<Match>> searchMatches(MatchSearch search) async {
    searches.add(search);
    return nearby.skip(search.offset).take(search.limit).toList();
  }

  @override
  Future<List<Match>> listMine() async => mine;

  @override
  Future<Match> getMatch(String id) async =>
      [...nearby, ...mine].firstWhere((m) => m.id == id);

  @override
  Future<List<Participant>> listParticipants(String matchId) async =>
      participants;

  @override
  Future<String> createMatch(MatchInput input) async {
    calls.add('create');
    inputs.add(input);
    if (createError != null) throw createError!;
    final match = fakeMatch(id: 'new', title: input.title, isOrganizer: true);
    mine = [match];
    return match.id;
  }

  @override
  Future<void> updateMatch(String id, MatchInput input) async {
    calls.add('update:$id');
    inputs.add(input);
  }

  @override
  Future<void> cancelMatch(String id) async => calls.add('cancel:$id');

  /// Erreur levée par la prochaine inscription ou désinscription, le cas échéant.
  AppError? participationError;

  @override
  Future<void> joinMatch(String id) async {
    calls.add('join:$id');
    if (participationError != null) throw participationError!;
  }

  @override
  Future<void> leaveMatch(String id) async {
    calls.add('leave:$id');
    if (participationError != null) throw participationError!;
  }

  /// Proposition en attente renvoyée pour tout match.
  Transfer? transfer;

  @override
  Future<Transfer?> pendingTransfer(String matchId) async => transfer;

  @override
  Future<void> proposeTransfer(String matchId, String toUserId) async =>
      calls.add('propose:$matchId:$toUserId');

  @override
  Future<void> cancelTransfer(String matchId) async =>
      calls.add('cancelTransfer:$matchId');

  @override
  Future<void> respondTransfer(
    String transferId, {
    required bool accept,
  }) async => calls.add('respond:$transferId:$accept');
}

Match fakeMatch({
  String id = 'm1',
  String title = 'Foot du dimanche',
  bool isOrganizer = false,
  bool isParticipant = false,
  String locationName = 'City stade des Rives',
  double latitude = 47.39,
  double longitude = 0.69,
  int capacity = 10,
  int participantCount = 1,
  MatchDisplayStatus displayStatus = MatchDisplayStatus.open,
  double? estimatedCostPerPlayer,
}) => Match(
  id: id,
  organizerId: 'orga',
  organizerName: 'Orga',
  title: title,
  startsAt: DateTime(2026, 11, 1, 14),
  durationMinutes: 90,
  capacity: capacity,
  participantCount: participantCount,
  spotsLeft: capacity - participantCount,
  format: MatchFormat.fiveASide,
  skillLevel: SkillLevel.all,
  locationName: locationName,
  latitude: latitude,
  longitude: longitude,
  estimatedCostPerPlayer: estimatedCostPerPlayer,
  displayStatus: displayStatus,
  isOrganizer: isOrganizer,
  isParticipant: isParticipant || isOrganizer,
);

class FakeLocationService implements LocationService {
  FakeLocationService({
    this.position = const GeoPoint(47.39, 0.69),
    this.error,
  });

  GeoPoint position;
  AppError? error;
  int calls = 0;

  @override
  Future<GeoPoint> currentPosition() async {
    calls++;
    if (error != null) throw error!;
    return position;
  }
}

class FakeGeocodingRepository implements GeocodingRepository {
  FakeGeocodingRepository({List<Place>? places}) : places = places ?? [];

  List<Place> places;
  AppError? error;
  final queries = <String>[];

  @override
  Future<List<Place>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return places;
  }
}

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? items})
    : items = items ?? [];

  List<AppNotification> items;
  int markAllReadCalls = 0;

  @override
  Future<List<AppNotification>> list() async => items;

  @override
  Future<int> unreadCount() async => items.where((n) => !n.isRead).length;

  @override
  Future<void> markAllRead() async {
    markAllReadCalls++;
    items = [
      for (final n in items)
        AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          body: n.body,
          matchId: n.matchId,
          date: n.date,
          isRead: true,
        ),
    ];
  }
}

Transfer fakeTransfer({String? fromName = 'Orga', String? toName = 'Alice'}) =>
    Transfer(
      id: 't1',
      matchId: 'm1',
      toUserId: 'alice',
      fromName: fromName,
      toName: toName,
      expiresAt: DateTime(2026, 10, 30, 10),
    );
