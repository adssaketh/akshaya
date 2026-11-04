import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import 'providers.dart';
import 'sync_ui.dart';

/// Sign in with Google or email and password, or create an account. Pops with
/// the [SignInOutcome]; backing out keeps the app signed out and fully usable.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<SignInOutcome> Function() action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final SignInOutcome outcome = await action();
      if (mounted) {
        navigator.pop(outcome);
      }
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final SyncController controller = ref.read(syncControllerProvider);
    final String email = _email.text.trim();
    final String password = _password.text;
    await _run(
      () => _register
          ? controller.register(email, password, _name.text.trim())
          : controller.signInWithEmail(email, password),
    );
  }

  Future<void> _reset() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String email = _email.text.trim();
    if (!email.contains('@')) {
      showMessage(messenger, 'Type your email first, then tap this again.');
      return;
    }
    try {
      await ref.read(syncControllerProvider).sendPasswordReset(email);
      showMessage(messenger, 'If that account exists, a reset email is on its way.');
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              'Signing in is optional. It lets you share a pantry with your '
              'household. Without it everything works on this phone.',
              style: context.akText.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref.read(syncControllerProvider).signInWithGoogle(),
                      ),
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _form,
              child: Column(
                children: <Widget>[
                  if (_register) ...<Widget>[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Your name (shown to your household)',
                      ),
                      validator: (String? v) => (v ?? '').trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (String? v) =>
                        (v ?? '').contains('@') ? null : 'Enter your email',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    autofillHints: const <String>[AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (String? v) => (v ?? '').length < 6
                        ? 'At least 6 characters'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_register ? 'Create account' : 'Sign in'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _register = !_register),
              child: Text(
                _register
                    ? 'I already have an account'
                    : 'Create an account with email',
              ),
            ),
            if (!_register)
              TextButton(
                onPressed: _busy ? null : _reset,
                child: const Text('Forgot password?'),
              ),
          ],
        ),
      ),
    );
  }
}
