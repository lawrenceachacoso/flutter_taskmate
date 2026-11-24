import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_providers.dart';
import '../../features/auth/controllers/profile_providers.dart';
import '../widgets/app_shell.dart';
import 'redirect_rules.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/verify_screen.dart';
import '../../features/auth/screens/account_problem_screen.dart';
import '../../features/auth/screens/suspended_screen.dart';
import '../../features/verification/screens/verification_status_screen.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/admin/screens/admin_jobs_screen.dart';
import '../../features/disputes/screens/admin_disputes_screen.dart';
import '../../features/jobs/screens/home_screen.dart';
import '../../features/jobs/screens/job_detail_screen.dart';
import '../../features/jobs/screens/post_job_screen.dart';
import '../../features/jobs/screens/my_jobs_screen.dart';
import '../../features/jobs/screens/applied_jobs_screen.dart';
import '../../features/ratings/screens/user_profile_screen.dart';
import '../../features/student_status/screens/student_request_screen.dart';
import '../../features/student_status/screens/admin_student_requests_screen.dart';

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
        profileFailed: profile.hasError,
        profile: profile.value,
        location: state.matchedLocation,
      );
    },
    routes: [
      // Pages outside the sidebar: sign in, verification, problems.
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) =>
            VerifyScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/pending', builder: (_, _) => const VerificationStatusScreen()),
      GoRoute(path: '/rejected', builder: (_, _) => const VerificationStatusScreen()),
      GoRoute(path: '/account-problem', builder: (_, _) => const AccountProblemScreen()),
      GoRoute(path: '/suspended', builder: (_, _) => const SuspendedScreen()),

      // Signed-in pages: all share the sidebar (wide) or bottom bar (phone).
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/jobs',
            builder: (_, _) => const MyJobsScreen(history: false),
          ),
          GoRoute(path: '/applied', builder: (_, _) => const AppliedJobsScreen()),
          GoRoute(
            path: '/history',
            builder: (_, _) => const MyJobsScreen(history: true),
          ),
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
          GoRoute(path: '/post-job', builder: (_, _) => const PostJobScreen()),
          GoRoute(
            path: '/jobs/:id',
            builder: (_, state) =>
                JobDetailScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/users/:id',
            builder: (_, state) =>
                UserProfileScreen(userId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/student-request',
            builder: (_, _) => const StudentRequestScreen(),
          ),
          GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
          GoRoute(path: '/admin/jobs', builder: (_, _) => const AdminJobsScreen()),
          GoRoute(
            path: '/admin/students',
            builder: (_, _) => const AdminStudentRequestsScreen(),
          ),
          GoRoute(
            path: '/admin/disputes',
            builder: (_, _) => const AdminDisputesScreen(),
          ),
        ],
      ),
    ],
  );
});
