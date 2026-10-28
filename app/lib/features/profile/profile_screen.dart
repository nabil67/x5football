import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/auth_repository.dart';
import '../../data/moderation_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../../ui/image_pick.dart';
import '../../ui/legal_links.dart';
import '../moderation/blocked_users_screen.dart';
import '../../ui/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.profiles,
    required this.auth,
    required this.onProfileChanged,
    required this.moderation,
    this.pickImage = pickImageWithPlugin,
  });

  final Profile profile;
  final ProfileRepository profiles;
  final AuthRepository auth;
  final ValueChanged<Profile> onProfileChanged;
  final ModerationRepository moderation;
  final PickImage pickImage;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile.displayName,
  );
  late Profile _profile = widget.profile;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_profile.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Retirer la photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      await _run(
        () async => _updated(await widget.profiles.removeAvatar()),
        success: 'Photo retirée.',
      );
      return;
    }
    await _run(() async {
      final image = await widget.pickImage(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (image == null) return;
      _updated(
        await widget.profiles.updateAvatar(
          image.bytes,
          extension: image.extension,
        ),
      );
    });
  }

  void _updated(Profile profile) {
    if (mounted) setState(() => _profile = profile);
    widget.onProfileChanged(profile);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final updated = await widget.profiles.updateDisplayName(
        _nameController.text.trim(),
      );
      widget.onProfileChanged(updated);
    }, success: 'Profil enregistré.');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer votre compte ?'),
        content: const Text(
          'Votre compte sera immédiatement désactivé puis définitivement supprimé. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer mon compte'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    await _run(() async {
      await widget.profiles.requestAccountDeletion();
      navigator.popUntil((route) => route.isFirst);
      await widget.auth.signOut();
    });
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await _run(() async {
      navigator.popUntil((route) => route.isFirst);
      await widget.auth.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Column(
                  children: [
                    UserAvatar(
                      name: _profile.displayName,
                      path: _profile.avatarUrl,
                      radius: 48,
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _changePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _profile.avatarUrl == null
                            ? 'Ajouter une photo'
                            : 'Changer la photo',
                      ),
                    ),
                    Text(
                      'Facultative, visible des joueurs connectés.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom affiché'),
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                validator: Profile.validateDisplayName,
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block),
                title: const Text('Joueurs bloqués'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        BlockedUsersScreen(moderation: widget.moderation),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Déconnexion'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _deleteAccount,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                child: const Text('Supprimer mon compte'),
              ),
              const SizedBox(height: 16),
              const LegalLinks(),
            ],
          ),
        ),
      ),
    );
  }
}
