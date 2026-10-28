import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_error.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

class PickedImage {
  const PickedImage(this.bytes, this.extension);

  final Uint8List bytes;

  /// `jpg`, `png` ou `webp`.
  final String extension;
}

/// Sélection d'une photo ; `null` si l'utilisateur annule. Injectable pour les tests.
typedef PickImage = Future<PickedImage?> Function(ImageSource source);

/// Photo réduite à 512 px et recompressée sur le téléphone avant envoi
/// (reste bien sous la limite de 1 Mo du serveur).
Future<PickedImage?> pickImageWithPlugin(ImageSource source) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null) return null;
    final name = file.name.toLowerCase();
    final extension = name.endsWith('.png')
        ? 'png'
        : name.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    return PickedImage(await file.readAsBytes(), extension);
  } on PlatformException {
    throw const AppError(
      'PHOTO_ACCESS_DENIED',
      'Impossible d\'accéder aux photos ou à l\'appareil photo. '
          'Vérifiez les autorisations dans les réglages du téléphone.',
    );
  }
}
