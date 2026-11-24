import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth_errors.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/auth_page.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final controller = ref.read(authControllerProvider.notifier);

    await controller.signIn(email: email, password: _passwordController.text);
    if (!mounted) return;

    // Signed up earlier but never entered the code: send a fresh code and
    // take them to the verify screen instead of leaving them stuck.
    final error = ref.read(authControllerProvider).error;
    if (error == null) {
      // Logged in. Go to a landing screen; the router then moves the user to
      // the right place once the profile has loaded.
      context.go('/pending');
      return;
    }
    if (isEmailNotConfirmed(error)) {
      await controller.resendOtp(email);
      if (!mounted) return;
      context.go('/verify?email=${Uri.encodeQueryComponent(email)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthPage(
      title: 'Welcome back',
      subtitle: 'Log in to your TaskMate account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            if (auth.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  friendlyAuthError(auth.error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _submit,
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log in'),
            ),
            TextButton(
              onPressed: () {
                // Clear any error so it does not follow the user.
                ref.invalidate(authControllerProvider);
                context.go('/signup');
              },
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
