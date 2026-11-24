import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/auth_page.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_providers.dart';

/// Shown when the user is logged in but their profile could not be loaded.
class AccountProblemScreen extends ConsumerWidget {
  const AccountProblemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    return AuthPage(
      title: 'Account problem',
      subtitle: 'We could not load your account details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            profile.hasError
                ? 'Check your internet connection and try again.'
                : 'No account record was found. Please contact the '
                    'administrators.',
          ),
          if (profile.hasError && kDebugMode) ...[
            const SizedBox(height: 8),
            Text('[${profile.error}]'),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref.invalidate(currentProfileProvider),
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
