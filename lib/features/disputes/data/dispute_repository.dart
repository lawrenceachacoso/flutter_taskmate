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

  Future<void> report(String jobId, String? details) async {
    await _client.rpc('report_nonpayment',
        params: {'p_job_id': jobId, 'p_details': details});
  }

  Future<void> submitProof(String disputeId, String proof) async {
    await _client.rpc('submit_payment_proof',
        params: {'p_dispute_id': disputeId, 'p_proof': proof});
  }

  Future<void> resolve(String disputeId,
      {required bool paid, String? note}) async {
    await _client.rpc('resolve_dispute',
        params: {'p_dispute_id': disputeId, 'p_paid': paid, 'p_note': note});
  }
}
