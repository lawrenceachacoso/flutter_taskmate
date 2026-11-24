import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/rating_controller.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;

  const UserProfileScreen({required this.userId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userRatingProvider(userId));
    final ratings = ref.watch(userRatingsProvider(userId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Profile'),
      ),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load this profile.${kDebugMode ? ' [$error]' : ''}'),
        ),
        data: (u) {
          if (u == null) {
            return const Center(child: Text('This profile is not available.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: u.fullName,
                    avatarPath: u.avatarPath,
                    radius: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName, style: text.headlineSmall),
                        const SizedBox(height: 4),
                        Text(u.label, style: text.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text('Ratings and comments', style: text.titleMedium),
              const SizedBox(height: 8),
              ratings.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Text('Could not load ratings.${kDebugMode ? ' [$error]' : ''}'),
                data: (list) => list.isEmpty
                    ? const Text('No ratings yet.')
                    : Column(
                        children: [
                          for (final r in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${'★' * r.stars}${'☆' * (5 - r.stars)}  ${r.raterName}',
                              ),
                              subtitle: r.comment == null ? null : Text(r.comment!),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
