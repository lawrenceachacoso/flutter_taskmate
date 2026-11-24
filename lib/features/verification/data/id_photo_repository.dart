import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class IdPhotoRepository {
  final SupabaseClient _client;

  const IdPhotoRepository(this._client);

  /// Uploads the photo to the private bucket under the user's own folder,
  /// then records the path on the profile through the database function.
  Future<void> upload({
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('id-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    await _client.rpc('submit_id_photo', params: {'p_path': path});
  }
}
