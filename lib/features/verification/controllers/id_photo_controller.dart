import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/controllers/auth_providers.dart';
import '../../auth/controllers/profile_providers.dart';
import '../data/id_photo_repository.dart';

const maxIdPhotoBytes = 5 * 1024 * 1024;

/// A problem with the chosen photo that is safe to show to the user as is.
class IdPhotoException implements Exception {
  final String message;

  const IdPhotoException(this.message);
}

final idPhotoRepositoryProvider = Provider<IdPhotoRepository>((ref) {
  return IdPhotoRepository(supabase);
});

class IdPhotoController extends AsyncNotifier<void> {
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

      await ref.read(idPhotoRepositoryProvider).upload(
            userId: user.id,
            bytes: bytes,
            extension: extension,
            contentType: contentType,
          );

      // Reload the profile so the router and the screen see the new state.
      ref.invalidate(currentProfileProvider);
    });
  }
}

final idPhotoControllerProvider =
    AsyncNotifierProvider.autoDispose<IdPhotoController, void>(
        IdPhotoController.new);
