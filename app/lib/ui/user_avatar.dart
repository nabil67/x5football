import 'package:flutter/material.dart';

/// Convertit un chemin du bucket privé `avatars` en image chargée avec le jeton de session.
typedef AvatarResolver = ImageProvider Function(String path);

/// Rend le chargement des photos disponible dans toute l'application.
/// Sans résolveur (ex. dans les tests), les initiales sont affichées.
class AvatarImages extends InheritedWidget {
  const AvatarImages({super.key, required this.resolve, required super.child});

  final AvatarResolver resolve;

  static ImageProvider? imageFor(BuildContext context, String? path) {
    if (path == null) return null;
    final scope = context.dependOnInheritedWidgetOfExactType<AvatarImages>();
    return scope?.resolve(path);
  }

  @override
  bool updateShouldNotify(AvatarImages oldWidget) => false;
}

/// Photo de profil, ou initiale du nom tant que la photo est absente, en cours de
/// chargement ou illisible. Décorative : le nom est toujours affiché à côté.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.path,
    this.radius = 20,
  });

  final String name;
  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = AvatarImages.imageFor(context, path);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        foregroundImage: image,
        onForegroundImageError: image == null ? null : (_, _) {},
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(fontSize: radius * 0.8),
        ),
      ),
    );
  }
}
