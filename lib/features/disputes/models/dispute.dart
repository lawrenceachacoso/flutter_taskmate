class Dispute {
  final String id;
  final String jobId;
  final String jobTitle;
  final String workerName;
  final String posterName;
  final double amount;
  final String? details;
  final String? proof;
  final String status;
  final String? adminNote;
  final DateTime createdAt;

  const Dispute({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.workerName,
    required this.posterName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.details,
    this.proof,
    this.adminNote,
  });

  factory Dispute.fromMap(Map<String, dynamic> map) {
    return Dispute(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      jobTitle: map['job_title'] as String,
      workerName: map['worker_name'] as String,
      posterName: map['poster_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      details: map['details'] as String?,
      proof: map['proof'] as String?,
      status: map['status'] as String,
      adminNote: map['admin_note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  bool get isResolved =>
      status == 'resolved_paid' || status == 'resolved_unpaid';
}
