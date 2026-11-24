import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/rating_controller.dart';

/// "★ 4.5 (3)" for a user. Tapping opens their profile page.
class RatingLabel extends ConsumerWidget {
  final String userId;

  const RatingLabel({required this.userId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(userRatingProvider(userId));
    return rating.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (r) => InkWell(
        onTap: () => context.push('/users/$userId'),
        child: Text(
          r == null ? 'No ratings yet' : r.label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
