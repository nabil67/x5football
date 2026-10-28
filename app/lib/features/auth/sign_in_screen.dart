import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/auth_repository.dart';
import '../../ui/legal_links.dart';

/// Connexion en deux temps : saisie de l'e-mail, puis du code reçu.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  String? _sentToEmail;
  bool _busy = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final email = _emailController.text.trim();
    await widget.auth.sendEmailCode(email);
    setState(() => _sentToEmail = email);
  });

  // En cas de succès, l'AuthGate change d'écran.
  Future<void> _verifyCode() => _run(
    () => widget.auth.verifyEmailCode(
      email: _sentToEmail!,
      code: _codeController.text.trim(),
    ),
  );

  void _changeEmail() => setState(() {
    _sentToEmail = null;
    _codeController.clear();
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final codeStep = _sentToEmail != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!codeStep) ...[
                const Text(
                  'Entrez votre e-mail : nous vous envoyons un code de connexion.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (_) => _busy ? null : _sendCode(),
                  validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Adresse e-mail invalide.',
                ),
              ] else ...[
                Text('Code envoyé à $_sentToEmail. Il est valable 10 minutes.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code à 6 chiffres',
                  ),
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _verifyCode(),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Le code contient 6 chiffres.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  semanticsLabel: 'Erreur : $_error',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : (codeStep ? _verifyCode : _sendCode),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(codeStep ? 'Se connecter' : 'Recevoir un code'),
              ),
              if (codeStep)
                TextButton(
                  onPressed: _busy ? null : _changeEmail,
                  child: const Text('Changer d\'adresse e-mail'),
                ),
              const SizedBox(height: 24),
              Text(
                'En continuant, vous acceptez les conditions d\'utilisation '
                'et la politique de confidentialité.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const LegalLinks(),
            ],
          ),
        ),
      ),
    );
  }
}
