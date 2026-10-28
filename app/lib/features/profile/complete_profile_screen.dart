import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';

/// Premier passage après connexion : nom d'affichage et attestation de majorité.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.profiles,
    required this.onCompleted,
    required this.onSignOut,
  });

  final ProfileRepository profiles;
  final ValueChanged<Profile> onCompleted;
  final VoidCallback onSignOut;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isAdult = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.profiles.completeProfile(
        displayName: _nameController.text.trim(),
        isAdult: _isAdult,
      );
      widget.onCompleted(profile);
    } on AppError catch (e) {
      // Session dont l'identité n'existe plus : retour à l'écran de connexion.
      if (e.code == 'AUTH_REQUIRED') return widget.onSignOut();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Votre profil'),
        actions: [
          TextButton(
            onPressed: _busy ? null : widget.onSignOut,
            child: const Text('Déconnexion'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom affiché',
                  helperText: 'Visible par les autres joueurs.',
                ),
                autofillHints: const [AutofillHints.nickname],
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                validator: Profile.validateDisplayName,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isAdult,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _isAdult = v ?? false),
                title: const Text('J\'atteste avoir 18 ans ou plus.'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  semanticsLabel: 'Erreur : $_error',
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || !_isAdult ? null : _submit,
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
