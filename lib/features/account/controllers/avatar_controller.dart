import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/controllers/auth_providers.dart';
import '../../auth/controllers/profile_providers.dart';
import '../../ratings/controllers/rating_controller.dart';
import '../../verification/controllers/id_photo_controller.dart'
    show IdPhotoException;
import '../data/avatar_repository.dart';

const maxAvatarBytes = 2 * 1024 * 1024;

String avatarError(Object error) {
  if (error is IdPhotoException) return error.message;
  if (error is StorageException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Something went wrong. Please try again.'
      '${kDebugMode ? ' [$error]' : ''}';
}

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return AvatarRepository(supabase);
});

class AvatarController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> change({
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
        throw const IdPhotoException('Please choose a JPG or PNG picture.');
      }

      if (bytes.length > maxAvatarBytes) {
        throw const IdPhotoException('That picture is too large. The limit is 2 MB.');
      }

      await ref.read(avatarRepositoryProvider).upload(
            userId: user.id,
            bytes: bytes,
            extension: extension,
            contentType: contentType,
          );

      ref.invalidate(currentProfileProvider);
      ref.invalidate(userRatingProvider(user.id));
    });
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider.autoDispose<AvatarController, void>(
        AvatarController.new);
