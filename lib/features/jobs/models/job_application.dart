class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String applicantId;
  final String applicantName;
  final String status;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.applicantId,
    required this.applicantName,
    required this.status,
  });

  factory JobApplication.fromMap(Map<String, dynamic> map) {
    return JobApplication(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      jobTitle: (map['job_title'] as String?) ?? '',
      applicantId: map['applicant_id'] as String,
      applicantName: map['applicant_name'] as String,
      status: map['status'] as String,
    );
  }

  /// "Pending", "Accepted" or "Not selected".
  String get statusLabel {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Not selected';
      default:
        return 'Pending';
    }
  }
}
