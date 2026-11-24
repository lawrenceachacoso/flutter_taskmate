import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';
import '../models/job_application.dart';
import '../models/job_contact.dart';

class JobRepository {
  final SupabaseClient _client;

  const JobRepository(this._client);

  /// Open jobs, newest first. Row level security limits what comes back.
  Future<List<Job>> fetchOpenJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return rows.map<Job>(Job.fromMap).toList();
  }

  /// Jobs the user posted or was accepted for, in any status.
  Future<List<Job>> fetchMyJobs(String userId) async {
    final rows = await _client
        .from('jobs')
        .select()
        .or('poster_id.eq.$userId,worker_id.eq.$userId')
        .order('created_at', ascending: false);
    return rows.map<Job>(Job.fromMap).toList();
  }

  /// The other party's contact details (database checks you may see them).
  Future<JobContact> fetchContact(String jobId) async {
    final result =
        await _client.rpc('get_job_contact', params: {'p_job_id': jobId});
    final rows = result as List;
    return JobContact.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> cancelJob(String jobId) async {
    await _client.rpc('cancel_job', params: {'p_job_id': jobId});
  }

  Future<void> markComplete(String jobId) async {
    await _client.rpc('mark_complete', params: {'p_job_id': jobId});
  }

  Future<Job?> fetchJob(String id) async {
    final row =
        await _client.from('jobs').select().eq('id', id).maybeSingle();
    return row == null ? null : Job.fromMap(row);
  }

  Future<void> apply(String jobId) async {
    await _client.from('applications').insert({'job_id': jobId});
  }

  /// The signed-in user's own application to this job, if any.
  Future<JobApplication?> fetchMyApplication(
      String jobId, String userId) async {
    final row = await _client
        .from('applications')
        .select()
        .eq('job_id', jobId)
        .eq('applicant_id', userId)
        .maybeSingle();
    return row == null ? null : JobApplication.fromMap(row);
  }

  /// Every application the user has sent, newest first.
  Future<List<JobApplication>> fetchMyApplications(String userId) async {
    final rows = await _client
        .from('applications')
        .select()
        .eq('applicant_id', userId)
        .order('created_at', ascending: false);
    return rows.map<JobApplication>(JobApplication.fromMap).toList();
  }

  /// Applications to a job. Only the poster gets rows other than their own.
  Future<List<JobApplication>> fetchApplications(String jobId) async {
    final rows = await _client
        .from('applications')
        .select()
        .eq('job_id', jobId)
        .order('created_at');
    return rows.map<JobApplication>(JobApplication.fromMap).toList();
  }

  Future<void> acceptApplication(String applicationId, double amount) async {
    await _client.rpc('accept_application',
        params: {'p_application_id': applicationId, 'p_amount': amount});
  }

  Future<void> setAgreedAmount(String jobId, double amount) async {
    await _client.rpc('set_agreed_amount',
        params: {'p_job_id': jobId, 'p_amount': amount});
  }

  Future<void> confirmAmount(String jobId) async {
    await _client.rpc('confirm_amount', params: {'p_job_id': jobId});
  }

  /// poster_id and poster_name are filled in by the database, not the app.
  /// Returns the saved job so the app can show its screening result.
  Future<Job> createJob({
    required String title,
    required String description,
    required String category,
    required double minPay,
    required bool negotiable,
    required String location,
  }) async {
    final row = await _client.from('jobs').insert({
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'min_pay': minPay,
      'negotiable': negotiable,
      'location': location.trim(),
    }).select().single();
    return Job.fromMap(row);
  }
}
