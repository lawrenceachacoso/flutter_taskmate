import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart' show roleLabel;
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/profile_providers.dart';
import '../../ratings/controllers/rating_controller.dart';

String _statusLabel(String status) {
  switch (status) {
    case 'verified':
      return 'Verified';
    case 'pending':
      return 'Pending verification';
    case 'rejected':
      return 'Verification rejected';
    case 'suspended':
      return 'Suspended';
    default:
      return status;
  }
}

/// The signed-in user's account: who they are, their rating, and log out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    // Watched only to keep the controller alive while it signs the user out.
    ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(currentProfileProvider),
            child: const Text('Could not load your account. Try again'),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Account not found.'));
          }
          final rating = ref.watch(userRatingProvider(profile.id)).value;
          final initial = profile.fullName.isEmpty
              ? '?'
              : profile.fullName.characters.first.toUpperCase();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: sunYellow,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: deepGreen,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text('${roleLabel(profile.role)} · '
                                '${_statusLabel(profile.status)}'),
                            Text(rating == null ? '' : rating.label),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('My public profile'),
                  subtitle: const Text('See the ratings and comments others left'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/users/${profile.id}'),
                ),
              ),
              if (profile.role == 'poster')
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('Are you a CMU student?'),
                    subtitle: const Text(
                        'Send your school ID or Certificate of Registration'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/student-request'),
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
