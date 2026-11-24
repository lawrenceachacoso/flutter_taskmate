class JobContact {
  final String fullName;
  final String? facebookUrl;
  final String? phone;

  const JobContact({required this.fullName, this.facebookUrl, this.phone});

  factory JobContact.fromMap(Map<String, dynamic> map) {
    return JobContact(
      fullName: map['full_name'] as String,
      facebookUrl: map['facebook_url'] as String?,
      phone: map['phone'] as String?,
    );
  }
}
