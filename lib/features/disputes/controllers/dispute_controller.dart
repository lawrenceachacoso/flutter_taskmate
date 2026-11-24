import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/controllers/auth_providers.dart';
import '../../verification/controllers/id_photo_controller.dart'
    show IdPhotoException, maxIdPhotoBytes;
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

  /// Checks and uploads the pictures, returning their storage paths. Files go
  /// to <job id>/<user id>/<file> in the private dispute-proof bucket.
  Future<List<String>> _upload(String jobId, List<ProofImage> images) async {
    if (images.isEmpty) return const [];
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      throw const IdPhotoException('Please log in again.');
    }

    final repo = ref.read(disputeRepositoryProvider);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final paths = <String>[];

    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final name = image.name.toLowerCase();
      final String extension;
      final String contentType;
      if (name.endsWith('.png')) {
        extension = 'png';
        contentType = 'image/png';
      } else if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
        extension = 'jpg';
        contentType = 'image/jpeg';
      } else {
        throw const IdPhotoException('Pictures must be JPG or PNG.');
      }
      if (image.bytes.length > maxIdPhotoBytes) {
        throw const IdPhotoException('A picture is too large. The limit is 5 MB each.');
      }
      paths.add(await repo.uploadProofImage(
        path: '$jobId/${user.id}/${stamp}_$i.$extension',
        bytes: image.bytes,
        contentType: contentType,
      ));
    }
    return paths;
  }

  Future<void> report(
    String jobId,
    String? details, {
    List<ProofImage> images = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final paths = await _upload(jobId, images);
      await ref.read(disputeRepositoryProvider).report(jobId, details, paths);
      ref.invalidate(jobDisputeProvider(jobId));
    });
  }

  Future<void> submitProof(
    String jobId,
    String disputeId,
    String? proof, {
    List<ProofImage> images = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final paths = await _upload(jobId, images);
      await ref
          .read(disputeRepositoryProvider)
          .submitProof(disputeId, proof, paths);
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
