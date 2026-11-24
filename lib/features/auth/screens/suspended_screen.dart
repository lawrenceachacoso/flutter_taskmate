import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/auth_page.dart';
import '../controllers/auth_controller.dart';

/// Shown to suspended users. They can only log out.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    return AuthPage(
      title: 'Account suspended',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your account is suspended, for example after an upheld '
            'non-payment report. Please contact the TaskMate administrators.',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
