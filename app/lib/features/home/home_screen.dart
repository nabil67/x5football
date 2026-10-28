import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../data/notification_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../matches/match_list_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.profiles,
    required this.auth,
    required this.matches,
    required this.geocoding,
    required this.location,
    required this.notifications,
    required this.onProfileChanged,
  });

  final Profile profile;
  final ProfileRepository profiles;
  final AuthRepository auth;
  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;
  final NotificationRepository notifications;
  final ValueChanged<Profile> onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return MatchListScreen(
      matches: matches,
      geocoding: geocoding,
      location: location,
      notifications: notifications,
      profileButton: IconButton(
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
    );
  }
}
