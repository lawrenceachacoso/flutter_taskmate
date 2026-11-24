import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rating.dart';

class RatingRepository {
  final SupabaseClient _client;

  const RatingRepository(this._client);

  Future<UserRating?> fetchUserRating(String userId) async {
    final row = await _client
        .from('public_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : UserRating.fromMap(row);
  }

  /// Ratings received by a user, newest first.
  Future<List<Rating>> fetchRatingsFor(String userId) async {
    final rows = await _client
        .from('ratings')
        .select()
        .eq('ratee_id', userId)
        .order('created_at', ascending: false);
    return rows.map<Rating>(Rating.fromMap).toList();
  }

  /// The rating this user already left for a job, if any.
  Future<Rating?> fetchMyRating(String jobId, String userId) async {
    final row = await _client
        .from('ratings')
        .select()
        .eq('job_id', jobId)
        .eq('rater_id', userId)
        .maybeSingle();
    return row == null ? null : Rating.fromMap(row);
  }

  Future<void> submit({
    required String jobId,
    required int stars,
    String? comment,
  }) async {
    await _client.rpc('submit_rating', params: {
      'p_job_id': jobId,
      'p_stars': stars,
      'p_comment': comment,
    });
  }
}
