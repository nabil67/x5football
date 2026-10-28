import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/auth_repository.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../data/moderation_repository.dart';
import '../../data/notification_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../home/home_screen.dart';
import '../profile/complete_profile_screen.dart';
import 'sign_in_screen.dart';

/// Choisit l'écran racine : connexion, création du profil, compte inactif ou accueil.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.profiles,
    required this.matches,
    required this.geocoding,
    required this.location,
    required this.notifications,
    required this.moderation,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;
  final NotificationRepository notifications;
  final ModerationRepository moderation;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _signedIn = widget.auth.isSignedIn;
  late final StreamSubscription<bool> _subscription;

  bool _loading = false;
  AppError? _loadError;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.signedInChanges.listen((signedIn) {
      if (signedIn == _signedIn) return;
      setState(() {
        _signedIn = signedIn;
        _profile = null;
      });
      if (signedIn) _loadProfile();
    });
    if (_signedIn) _loadProfile();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await widget.profiles.fetchMyProfile();
      if (mounted) setState(() => _profile = profile);
    } on AppError catch (e) {
      if (e.code == 'AUTH_REQUIRED') return _signOut();
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setProfile(Profile profile) => setState(() => _profile = profile);

  Future<void> _signOut() async {
    try {
      await widget.auth.signOut();
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) return SignInScreen(auth: widget.auth);

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
      );
    }

    if (_loadError != null) {
      return _MessageScreen(
        message: _loadError!.message,
        actionLabel: 'Réessayer',
        onAction: _loadProfile,
        onSignOut: _signOut,
      );
    }

    final profile = _profile;
    if (profile == null) {
      return CompleteProfileScreen(
        profiles: widget.profiles,
        onCompleted: _setProfile,
        onSignOut: _signOut,
      );
    }

    if (!profile.isActive) {
      return _MessageScreen(
        message: profile.accountStatus == AccountStatus.suspended
            ? 'Votre compte est suspendu.'
            : 'Votre compte est en cours de suppression.',
        onSignOut: _signOut,
      );
    }

    return HomeScreen(
      profile: profile,
      profiles: widget.profiles,
      auth: widget.auth,
      matches: widget.matches,
      geocoding: widget.geocoding,
      location: widget.location,
      notifications: widget.notifications,
      moderation: widget.moderation,
      onProfileChanged: _setProfile,
    );
  }
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.message,
    required this.onSignOut,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (onAction != null)
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Déconnexion'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
