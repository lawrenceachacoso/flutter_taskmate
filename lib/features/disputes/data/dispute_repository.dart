import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dispute.dart';

class DisputeRepository {
  final SupabaseClient _client;

  const DisputeRepository(this._client);

  /// The dispute for a job, if one exists (row level security limits access).
  Future<Dispute?> fetchForJob(String jobId) async {
    final row = await _client
        .from('disputes')
        .select()
        .eq('job_id', jobId)
        .maybeSingle();
    return row == null ? null : Dispute.fromMap(row);
  }

  /// Unresolved disputes, oldest first (admins only see others' rows).
  Future<List<Dispute>> fetchUnresolved() async {
    final rows = await _client
        .from('disputes')
        .select()
        .inFilter('status', ['open', 'proof_submitted'])
        .order('created_at');
    return rows.map<Dispute>(Dispute.fromMap).toList();
  }

  /// Uploads one proof picture to the private bucket and returns its path.
  Future<String> uploadProofImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage.from('dispute-proof').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  }

  Future<void> report(String jobId, String? details, List<String> paths) async {
    await _client.rpc('report_nonpayment', params: {
      'p_job_id': jobId,
      'p_details': details,
      'p_paths': paths,
    });
  }

  Future<void> submitProof(
      String disputeId, String? proof, List<String> paths) async {
    await _client.rpc('submit_payment_proof', params: {
      'p_dispute_id': disputeId,
      'p_proof': proof,
      'p_paths': paths,
    });
  }

  Future<void> resolve(String disputeId,
      {required bool paid, String? note}) async {
    await _client.rpc('resolve_dispute',
        params: {'p_dispute_id': disputeId, 'p_paid': paid, 'p_note': note});
  }
}
