import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_providers.dart';
import '../../features/auth/controllers/profile_providers.dart';
import '../widgets/placeholder_screen.dart';
import 'redirect_rules.dart';
import '../../features/auth/screens/login_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final profile = ref.read(currentProfileProvider);
      return computeRedirect(
        loggedIn: loggedIn,
        profileLoading: profile.isLoading,
        profile: profile.value,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const PlaceholderScreen('Sign up')),
      GoRoute(path: '/verify', builder: (_, _) => const PlaceholderScreen('Verify email')),
      GoRoute(path: '/pending', builder: (_, _) => const PlaceholderScreen('Pending review')),
      GoRoute(path: '/rejected', builder: (_, _) => const PlaceholderScreen('Rejected')),
      GoRoute(path: '/suspended', builder: (_, _) => const PlaceholderScreen('Suspended')),
      GoRoute(path: '/home', builder: (_, _) => const PlaceholderScreen('Home')),
      GoRoute(path: '/admin', builder: (_, _) => const PlaceholderScreen('Admin')),
    ],
  );
});