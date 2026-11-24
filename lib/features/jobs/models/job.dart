class Job {
  final String id;
  final String posterId;
  final String posterName;
  final String title;
  final String description;
  final String category;
  final double minPay;
  final bool negotiable;
  final String location;
  final String status;
  final String? workerId;
  final int applicantCount;
  final bool posterDone;
  final bool workerDone;
  final DateTime? completedAt;
  final double? agreedAmount;
  final bool amountConfirmed;
  final String riskLevel;
  final List<String> riskReasons;
  final String? reviewNote;
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.posterId,
    required this.posterName,
    required this.title,
    required this.description,
    required this.category,
    required this.minPay,
    required this.negotiable,
    required this.location,
    required this.status,
    required this.applicantCount,
    required this.posterDone,
    required this.workerDone,
    this.workerId,
    this.completedAt,
    this.agreedAmount,
    required this.amountConfirmed,
    required this.riskLevel,
    required this.riskReasons,
    this.reviewNote,
    required this.createdAt,
  });

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] as String,
      posterId: map['poster_id'] as String,
      posterName: map['poster_name'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      minPay: (map['min_pay'] as num).toDouble(),
      negotiable: map['negotiable'] as bool,
      location: map['location'] as String,
      status: map['status'] as String,
      workerId: map['worker_id'] as String?,
      applicantCount: map['applicant_count'] as int,
      posterDone: map['poster_done'] as bool,
      workerDone: map['worker_done'] as bool,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String).toLocal(),
      agreedAmount: (map['agreed_amount'] as num?)?.toDouble(),
      amountConfirmed: map['amount_confirmed'] as bool,
      riskLevel: map['risk_level'] as String,
      riskReasons: (map['risk_reasons'] as List).cast<String>(),
      reviewNote: map['review_note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  /// Agreed amount as text, e.g. "₱500".
  String get agreedLabel => agreedAmount == null ? '-' : '₱${formatPeso(agreedAmount!)}';

  /// Text shown on cards, e.g. "From ₱150" or "From ₱150 (negotiable)".
  String get payLabel {
    return 'From ₱${formatPeso(minPay)}${negotiable ? ' (negotiable)' : ''}';
  }
}

/// Friendly text for a job status stored in the database.
String jobStatusLabel(String status) {
  switch (status) {
    case 'pending_review':
      return 'Waiting for review';
    case 'open':
      return 'Open';
    case 'in_progress':
      return 'In progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'blocked':
      return 'Blocked';
    default:
      return status;
  }
}

/// 150 -> "150", 150.5 -> "150.50".
String formatPeso(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
