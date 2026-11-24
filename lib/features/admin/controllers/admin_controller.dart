import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/models/profile.dart';
import '../../jobs/controllers/job_controller.dart';
import '../../jobs/models/job.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(supabase);
});

final pendingProfilesProvider =
    FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchPending();
});

final pendingJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchPendingJobs();
});

final idPhotoBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, path) {
  return ref.watch(adminRepositoryProvider).downloadIdPhoto(path);
});

class AdminReviewController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> reviewJob({
    required String jobId,
    required bool approve,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(adminRepositoryProvider)
          .reviewJob(jobId: jobId, approve: approve, note: note);
      ref.invalidate(pendingJobsProvider);
      ref.invalidate(openJobsProvider);
    });
  }

  Future<void> review({
    required String userId,
    required bool approve,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(adminRepositoryProvider)
          .review(userId: userId, approve: approve, reason: reason);
      ref.invalidate(pendingProfilesProvider);
    });
  }
}

final adminReviewControllerProvider =
    AsyncNotifierProvider.autoDispose<AdminReviewController, void>(
        AdminReviewController.new);
