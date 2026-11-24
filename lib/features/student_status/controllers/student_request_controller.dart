import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/controllers/auth_providers.dart';
import '../../verification/controllers/id_photo_controller.dart'
    show IdPhotoException, maxIdPhotoBytes;
import '../data/student_request_repository.dart';
import '../models/student_request.dart';

final studentRequestRepositoryProvider =
    Provider<StudentRequestRepository>((ref) {
  return StudentRequestRepository(supabase);
});

final myStudentRequestProvider =
    FutureProvider.autoDispose<StudentRequest?>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ref.watch(studentRequestRepositoryProvider).fetchLatest(user.id);
});

final pendingStudentRequestsProvider =
    FutureProvider.autoDispose<List<StudentRequest>>((ref) {
  return ref.watch(studentRequestRepositoryProvider).fetchPending();
});

final studentDocumentProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, path) {
  return ref.watch(studentRequestRepositoryProvider).downloadDocument(path);
});

/// Poster submits a document; admin approves or rejects.
class StudentRequestController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required Uint8List bytes,
    required String fileName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) {
        throw const IdPhotoException('Please log in again.');
      }

      final name = fileName.toLowerCase();
      final String extension;
      final String contentType;
      if (name.endsWith('.png')) {
        extension = 'png';
        contentType = 'image/png';
      } else if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
        extension = 'jpg';
        contentType = 'image/jpeg';
      } else {
        throw const IdPhotoException('Please choose a JPG or PNG photo.');
      }
      if (bytes.length > maxIdPhotoBytes) {
        throw const IdPhotoException('That photo is too large. The limit is 5 MB.');
      }

      await ref.read(studentRequestRepositoryProvider).submit(
            userId: user.id,
            bytes: bytes,
            extension: extension,
            contentType: contentType,
          );
      ref.invalidate(myStudentRequestProvider);
    });
  }

  Future<void> review({
    required String requestId,
    required bool approve,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(studentRequestRepositoryProvider)
          .review(requestId: requestId, approve: approve, reason: reason);
      ref.invalidate(pendingStudentRequestsProvider);
    });
  }
}

final studentRequestControllerProvider =
    AsyncNotifierProvider.autoDispose<StudentRequestController, void>(
        StudentRequestController.new);
