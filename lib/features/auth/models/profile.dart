class Profile {
  final String id;
  final String fullName;
  final String role;
  final String status;
  final String? idPhotoPath;
  final String? rejectionReason;

  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.status,
    this.idPhotoPath,
    this.rejectionReason,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      status: map['status'] as String,
      idPhotoPath: map['id_photo_path'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}