import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/auth_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile.displayName,
  );
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
            ],
          ),
        ),
      ),
    );
  }
}
