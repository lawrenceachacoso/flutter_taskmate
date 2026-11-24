/// A user's public rating summary (from the public_profiles view).
class UserRating {
  final String id;
  final String fullName;
  final double average;
  final int count;
  final String? avatarPath;

  const UserRating({
    required this.id,
    required this.fullName,
    required this.average,
    required this.count,
    this.avatarPath,
  });

  factory UserRating.fromMap(Map<String, dynamic> map) {
    return UserRating(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      average: (map['rating_avg'] as num).toDouble(),
      count: map['rating_count'] as int,
      avatarPath: map['avatar_path'] as String?,
    );
  }

  /// "★ 4.5 (3)", or "No ratings yet".
  String get label =>
      count == 0 ? 'No ratings yet' : '★ ${average.toStringAsFixed(1)} ($count)';
}

/// One rating left by one user for another after a completed job.
class Rating {
  final String id;
  final String jobId;
  final String raterName;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.jobId,
    required this.raterName,
    required this.stars,
    required this.createdAt,
    this.comment,
  });

  factory Rating.fromMap(Map<String, dynamic> map) {
    return Rating(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      raterName: map['rater_name'] as String,
      stars: map['stars'] as int,
      comment: map['comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}
