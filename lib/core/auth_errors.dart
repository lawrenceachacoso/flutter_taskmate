import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when Supabase refused a login because the email was never confirmed.
bool isEmailNotConfirmed(Object error) {
  if (error is AuthException) {
    return error.code == 'email_not_confirmed' ||
        error.message.toLowerCase().contains('not confirmed');
  }
  return false;
}

/// Turns any error into a short message that is safe to show a user.
String friendlyAuthError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    final code = error.code ?? '';

    if (code == 'invalid_credentials' || msg.contains('invalid login')) {
      return 'Wrong email or password.';
    }
    if (isEmailNotConfirmed(error)) {
      return 'Please verify your email first.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('database error saving new user')) {
      return 'Sign-up was rejected. Students must use a @cmu.edu.ph email.';
    }
    if (code == 'otp_expired' ||
        msg.contains('expired') ||
        msg.contains('invalid') && msg.contains('token')) {
      return 'That code is wrong, expired, or already used. If you already '
          'verified your email, go back and log in. Otherwise tap "Resend '
          'code" for a new one.';
    }
    if (code.contains('rate_limit') || msg.contains('rate limit')) {
      return 'Too many requests. Please wait a minute and try again.';
    }
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('clientexception')) {
    return 'Cannot reach the server. Check your internet connection.';
  }
  // In debug runs, append the raw error so it can be copied into a bug report.
  final detail = kDebugMode ? ' [$error]' : '';
  return 'Something went wrong. Please try again.$detail';
}
