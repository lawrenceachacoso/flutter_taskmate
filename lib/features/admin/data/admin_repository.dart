import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/models/profile.dart';
import '../../jobs/models/job.dart';

class AdminRepository {
  final SupabaseClient _client;

  const AdminRepository(this._client);

  /// Profiles that submitted an ID photo and are waiting for a decision.
  Future<List<Profile>> fetchPending() async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('status', 'pending')
        .not('id_photo_path', 'is', null)
        .order('created_at');
    return rows.map<Profile>(Profile.fromMap).toList();
  }

  /// Jobs waiting for an admin decision, oldest first.
  Future<List<Job>> fetchPendingJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('status', 'pending_review')
        .order('created_at');
    return rows.map<Job>(Job.fromMap).toList();
  }

  /// Approve (job becomes open) or reject (job becomes blocked).
  Future<void> reviewJob({
    required String jobId,
    required bool approve,
    String? note,
  }) {
    return _client.rpc('review_job', params: {
      'p_job_id': jobId,
      'p_approve': approve,
      'p_note': note,
    });
  }

  /// Downloads the photo bytes (allowed for admins by the storage policy).
  Future<Uint8List> downloadIdPhoto(String path) {
    return _client.storage.from('id-photos').download(path);
  }

  /// Calls the review_profile database function (admins only).
  Future<void> review({
    required String userId,
    required bool approve,
    String? reason,
  }) {
    return _client.rpc('review_profile', params: {
      'p_user_id': userId,
      'p_decision': approve ? 'verified' : 'rejected',
      'p_reason': reason,
    });
  }
}
