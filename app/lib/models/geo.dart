import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Distance à vol d'oiseau en kilomètres (formule de haversine).
  double distanceKmTo(GeoPoint other) {
    const earthRadiusKm = 6371.0088;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(a));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Résultat d'une recherche d'adresse.
class Place {
  const Place({required this.name, required this.label, required this.point});

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['name'] as String,
    label: json['label'] as String,
    point: GeoPoint(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
  );

  /// Nom court, proposé comme nom du terrain.
  final String name;

  /// Adresse complète.
  final String label;
  final GeoPoint point;
}
