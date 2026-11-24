class StudentRequest {
  final String id;
  final String userId;
  final String userName;
  final String documentPath;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  const StudentRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.documentPath,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  factory StudentRequest.fromMap(Map<String, dynamic> map) {
    return StudentRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      documentPath: map['document_path'] as String,
      status: map['status'] as String,
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}
