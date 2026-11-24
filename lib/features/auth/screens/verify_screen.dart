import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth_errors.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/auth_page.dart';
import '../controllers/auth_controller.dart';

/// Seconds the user must wait before asking for another code. Supabase also
/// limits how often it will send one, so this stops pointless repeat taps.
const resendCooldownSeconds = 60;

class VerifyScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyScreen({required this.email, super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  Timer? _timer;
  int _cooldown = resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    // A code was just sent (at sign-up or log-in), so start the wait now.
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = resendCooldownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).verifyOtp(
          email: widget.email,
          code: _codeController.text.trim(),
        );
    if (!mounted) return;
    if (!ref.read(authControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified. Your account is registered.'),
        ),
      );
      // Verifying also signs the user in. The router moves them on to the
      // right screen (ID upload, or home if already verified).
      context.go('/pending');
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    await ref.read(authControllerProvider.notifier).resendOtp(widget.email);
    if (!mounted) return;
    if (!ref.read(authControllerProvider).hasError) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A new code was requested for ${widget.email}. It can take a '
            'minute to arrive. Check your spam folder too.',
          ),
        ),
      );
    }
  }

  void _backToLogin() {
    // Clear any error so it does not follow the user to the login screen.
    ref.invalidate(authControllerProvider);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthPage(
      title: 'Verify your email',
      subtitle: 'We sent a $otpLength-digit code to ${widget.email}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              keyboardType: TextInputType.number,
              maxLength: otpLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: validateOtp,
            ),
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
                  : const Text('Verify'),
            ),
            TextButton(
              onPressed: (auth.isLoading || _cooldown > 0) ? null : _resend,
              child: Text(
                _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
              ),
            ),
            TextButton(
              onPressed: _backToLogin,
              child: const Text('Back to log in'),
            ),
          ],
        ),
      ),
    );
  }
}
