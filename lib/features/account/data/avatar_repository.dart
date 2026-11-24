import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarRepository {
  final SupabaseClient _client;

  const AvatarRepository(this._client);

  /// Uploads into the public avatars bucket under the user's own folder, then
  /// saves the path on the profile through the database function. A new file
  /// name each time means browsers never show a stale cached picture.
  Future<void> upload({
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    await _client.rpc('set_avatar', params: {'p_path': path});
  }
}
