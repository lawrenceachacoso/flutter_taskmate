import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../data/dispute_repository.dart';
import '../models/dispute.dart';

final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  return DisputeRepository(supabase);
});

final jobDisputeProvider =
    FutureProvider.autoDispose.family<Dispute?, String>((ref, jobId) {
  return ref.watch(disputeRepositoryProvider).fetchForJob(jobId);
});

final unresolvedDisputesProvider =
    FutureProvider.autoDispose<List<Dispute>>((ref) {
  return ref.watch(disputeRepositoryProvider).fetchUnresolved();
});

/// Report non-payment, submit proof, or (admin) resolve a dispute.
class DisputeController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> report(String jobId, String? details) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(disputeRepositoryProvider).report(jobId, details);
      ref.invalidate(jobDisputeProvider(jobId));
    });
  }

  Future<void> submitProof(String jobId, String disputeId, String proof) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(disputeRepositoryProvider).submitProof(disputeId, proof);
      ref.invalidate(jobDisputeProvider(jobId));
    });
  }

  Future<void> resolve(String disputeId,
      {required bool paid, String? note}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(disputeRepositoryProvider)
          .resolve(disputeId, paid: paid, note: note);
      ref.invalidate(unresolvedDisputesProvider);
    });
  }
}

final disputeControllerProvider =
    AsyncNotifierProvider.autoDispose<DisputeController, void>(
        DisputeController.new);
