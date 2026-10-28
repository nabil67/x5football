import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../profile/profile_screen.dart';

/// Accueil provisoire ; la liste des matchs arrive aux étapes 3 et 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.profiles,
    required this.auth,
    required this.onProfileChanged,
  });

  final Profile profile;
  final ProfileRepository profiles;
  final AuthRepository auth;
  final ValueChanged<Profile> onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('x5football'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Mon profil',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(
                  profile: profile,
                  profiles: profiles,
                  auth: auth,
                  onProfileChanged: onProfileChanged,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(child: Text('Bonjour ${profile.displayName} !')),
    );
  }
}
