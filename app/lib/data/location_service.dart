import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo.dart';
import 'app_error.dart';

/// Position du téléphone, demandée uniquement à l'initiative de l'utilisateur.
/// Elle n'est jamais enregistrée : elle sert de point de recherche ou de position de terrain.
abstract interface class LocationService {
  Future<GeoPoint> currentPosition();
}

class GeolocatorLocationService implements LocationService {
  static const _denied = AppError(
    'LOCATION_DENIED',
    'Accès à la position refusé. Recherchez plutôt une ville ou une adresse.',
  );

  @override
  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppError(
        'LOCATION_DISABLED',
        'La localisation du téléphone est désactivée. Activez-la ou recherchez une ville.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw _denied;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on PermissionDeniedException {
      throw _denied;
    } catch (e) {
      // Pas de position fraîche (délai dépassé, GPS lent) : dernière position connue du téléphone.
      debugPrint('Localisation : ${e.runtimeType}');
      final last = await Geolocator.getLastKnownPosition().catchError(
        (_) => null,
      );
      if (last != null) return GeoPoint(last.latitude, last.longitude);
      throw const AppError(
        'LOCATION_UNAVAILABLE',
        'Position introuvable pour le moment. Réessayez ou recherchez une ville.',
      );
    }
  }
}
