import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(supabase);
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  // Watched so the profile reloads whenever someone logs in or out.
  ref.watch(authStateProvider);

  // Read the user straight from the client. A saved session is available
  // right at app start, before the auth stream has delivered its first event.
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(user.id);
});
