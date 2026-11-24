import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/controllers/auth_providers.dart';
import '../data/job_repository.dart';
import '../models/job.dart';
import '../models/job_application.dart';
import '../models/job_contact.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(supabase);
});

final openJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) {
  return ref.watch(jobRepositoryProvider).fetchOpenJobs();
});

final jobProvider = FutureProvider.autoDispose.family<Job?, String>((ref, id) {
  return ref.watch(jobRepositoryProvider).fetchJob(id);
});

final jobContactProvider =
    FutureProvider.autoDispose.family<JobContact, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).fetchContact(jobId);
});

final myJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return ref.watch(jobRepositoryProvider).fetchMyJobs(user.id);
});

final myApplicationsProvider =
    FutureProvider.autoDispose<List<JobApplication>>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return ref.watch(jobRepositoryProvider).fetchMyApplications(user.id);
});

final myApplicationProvider = FutureProvider.autoDispose
    .family<JobApplication?, String>((ref, jobId) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ref.watch(jobRepositoryProvider).fetchMyApplication(jobId, user.id);
});

final jobApplicationsProvider = FutureProvider.autoDispose
    .family<List<JobApplication>, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).fetchApplications(jobId);
});

/// Apply to a job, or accept an applicant. Refreshes the affected screens.
class JobActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> apply(String jobId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(jobRepositoryProvider).apply(jobId);
      ref.invalidate(myApplicationProvider(jobId));
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(jobProvider(jobId));
    });
  }

  Future<void> cancel(String jobId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(jobRepositoryProvider).cancelJob(jobId);
      ref.invalidate(jobProvider(jobId));
      ref.invalidate(jobApplicationsProvider(jobId));
      ref.invalidate(openJobsProvider);
      ref.invalidate(myJobsProvider);
    });
  }

  Future<void> complete(String jobId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(jobRepositoryProvider).markComplete(jobId);
      ref.invalidate(jobProvider(jobId));
      ref.invalidate(myJobsProvider);
    });
  }

  Future<void> setAmount(String jobId, double amount) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(jobRepositoryProvider).setAgreedAmount(jobId, amount);
      ref.invalidate(jobProvider(jobId));
    });
  }

  Future<void> confirmAmount(String jobId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(jobRepositoryProvider).confirmAmount(jobId);
      ref.invalidate(jobProvider(jobId));
    });
  }

  Future<void> accept({
    required String applicationId,
    required String jobId,
    required double amount,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(jobRepositoryProvider)
          .acceptApplication(applicationId, amount);
      ref.invalidate(jobApplicationsProvider(jobId));
      ref.invalidate(jobProvider(jobId));
      ref.invalidate(openJobsProvider);
      ref.invalidate(myJobsProvider);
    });
  }
}

final jobActionControllerProvider =
    AsyncNotifierProvider.autoDispose<JobActionController, void>(
        JobActionController.new);

class PostJobController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Returns the saved job (with its screening result), or null on error.
  Future<Job?> post({
    required String title,
    required String description,
    required String category,
    required double minPay,
    required bool negotiable,
    required String location,
  }) async {
    Job? created;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      created = await ref.read(jobRepositoryProvider).createJob(
            title: title,
            description: description,
            category: category,
            minPay: minPay,
            negotiable: negotiable,
            location: location,
          );
      ref.invalidate(openJobsProvider);
      ref.invalidate(myJobsProvider);
    });
    return created;
  }
}

final postJobControllerProvider =
    AsyncNotifierProvider.autoDispose<PostJobController, void>(
        PostJobController.new);
