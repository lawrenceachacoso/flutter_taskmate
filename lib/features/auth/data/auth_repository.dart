import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  const AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String facebookUrl,
    required String phone,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
        'facebook_url': facebookUrl,
        'phone': phone,
      },
    );
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: code,
    );
  }

  Future<void> resendSignupOtp(String email) {
    return _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}