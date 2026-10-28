import 'dart:async';

import 'package:x5football/data/app_error.dart';
import 'package:x5football/data/auth_repository.dart';
import 'package:x5football/data/profile_repository.dart';
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
