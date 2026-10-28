import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/geo.dart';
import 'app_error.dart';

/// Recherche d'adresses dans le monde entier (Edge Function `geocode`,
/// données OpenStreetMap). Le fournisseur peut être remplacé sans toucher à l'interface.
abstract interface class GeocodingRepository {
  Future<List<Place>> search(String query);
}

class SupabaseGeocodingRepository implements GeocodingRepository {
  SupabaseGeocodingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Place>> search(String query) async {
    try {
      final response = await _client.functions.invoke(
        'geocode',
        body: {'query': query},
      );
      final places = (response.data as Map<String, dynamic>)['places'] as List;
      return places.cast<Map<String, dynamic>>().map(Place.fromJson).toList();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
