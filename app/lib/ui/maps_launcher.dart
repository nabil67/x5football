import 'package:url_launcher/url_launcher.dart';

import '../models/geo.dart';

/// Ouvre une URL hors de l'application ; renvoie `false` en cas d'échec.
typedef OpenExternalUrl = Future<bool> Function(Uri uri);

Future<bool> openExternalUrl(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Lien universel Google Maps : ouvre l'application si elle est installée,
/// sinon le navigateur (Android et iOS), sans clé ni compte.
Uri mapsUri(GeoPoint point) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': '${point.latitude},${point.longitude}',
});
