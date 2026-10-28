import 'dart:async';

import 'package:x5football/data/app_error.dart';
import 'package:x5football/data/auth_repository.dart';
import 'package:x5football/data/match_repository.dart';
import 'package:x5football/data/profile_repository.dart';
import 'package:x5football/models/match.dart';
import 'package:x5football/models/profile.dart';

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
  Future<void> requestAccountDeletion() async => calls.add('delete');
}

class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository({
    List<Match>? upcoming,
    List<Match>? mine,
    this.participants = const [],
  }) : upcoming = upcoming ?? [],
       mine = mine ?? [];

  List<Match> upcoming;
  List<Match> mine;
  List<Participant> participants;
  final calls = <String>[];
  final inputs = <MatchInput>[];
  AppError? createError;

  @override
  Future<List<Match>> listUpcoming() async => upcoming;

  @override
  Future<List<Match>> listMine() async => mine;

  @override
  Future<Match> getMatch(String id) async =>
      [...upcoming, ...mine].firstWhere((m) => m.id == id);

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
}

Match fakeMatch({
  String id = 'm1',
  String title = 'Foot du dimanche',
  bool isOrganizer = false,
  bool isParticipant = false,
  LocationMode locationMode = LocationMode.toDefine,
  String? locationName = 'Centre-ville',
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
  locationMode: locationMode,
  locationName: locationName,
  latitude: locationMode == LocationMode.fixed ? 47.39 : null,
  longitude: locationMode == LocationMode.fixed ? 0.69 : null,
  estimatedCostPerPlayer: estimatedCostPerPlayer,
  displayStatus: displayStatus,
  isOrganizer: isOrganizer,
  isParticipant: isParticipant || isOrganizer,
);
