import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_request.dart';

class StudentRequestRepository {
  final SupabaseClient _client;

  const StudentRequestRepository(this._client);

  /// Uploads the document, then records the request through the database.
  Future<void> submit({
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('student-docs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    await _client.rpc('request_student_status', params: {'p_path': path});
  }

  /// The user's latest request, if any.
  Future<StudentRequest?> fetchLatest(String userId) async {
    final row = await _client
        .from('student_requests')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : StudentRequest.fromMap(row);
  }

  /// Pending requests for the admin queue, oldest first.
  Future<List<StudentRequest>> fetchPending() async {
    final rows = await _client
        .from('student_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return rows.map<StudentRequest>(StudentRequest.fromMap).toList();
  }

  Future<Uint8List> downloadDocument(String path) {
    return _client.storage.from('student-docs').download(path);
  }

  Future<void> review({
    required String requestId,
    required bool approve,
    String? reason,
  }) async {
    await _client.rpc('review_student_request', params: {
      'p_request_id': requestId,
      'p_approve': approve,
      'p_reason': reason,
    });
  }
}
