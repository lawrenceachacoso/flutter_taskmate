import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/controllers/auth_providers.dart';
import '../data/rating_repository.dart';
import '../models/rating.dart';

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(supabase);
});

final userRatingProvider =
    FutureProvider.autoDispose.family<UserRating?, String>((ref, userId) {
  return ref.watch(ratingRepositoryProvider).fetchUserRating(userId);
});

final userRatingsProvider =
    FutureProvider.autoDispose.family<List<Rating>, String>((ref, userId) {
  return ref.watch(ratingRepositoryProvider).fetchRatingsFor(userId);
});

final myRatingProvider =
    FutureProvider.autoDispose.family<Rating?, String>((ref, jobId) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ref.watch(ratingRepositoryProvider).fetchMyRating(jobId, user.id);
});

class RatingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required String jobId,
    required String rateeId,
    required int stars,
    String? comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(ratingRepositoryProvider)
          .submit(jobId: jobId, stars: stars, comment: comment);
      ref.invalidate(myRatingProvider(jobId));
      ref.invalidate(userRatingProvider(rateeId));
      ref.invalidate(userRatingsProvider(rateeId));
    });
  }
}

final ratingControllerProvider =
    AsyncNotifierProvider.autoDispose<RatingController, void>(
        RatingController.new);
