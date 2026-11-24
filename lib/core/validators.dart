String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Email is required';
  if (!text.contains('@')) return 'Enter a valid email';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Use at least 8 characters';
  return null;
}

String? validateEmailForRole(String? value, String role) {
  final base = validateEmail(value);
  if (base != null) return base;
  if (role == 'student' &&
      !value!.trim().toLowerCase().endsWith('@cmu.edu.ph')) {
    return 'Students must use a @cmu.edu.ph email';
  }
  return null;
}

/// Must match Supabase Auth > Email OTP Length (set to 8).
const otpLength = 8;

String? validateOtp(String? value) {
  final text = value?.trim() ?? '';
  if (text.length != otpLength) return 'Enter the $otpLength-digit code';
  return null;
}

/// The 10 job categories. Must match the check constraint in 005_jobs.sql.
const jobCategories = [
  'Desk work',
  'Academic help',
  'Tech help',
  'Creative and designs',
  'Manual labor',
  'Delivery and errands',
  'Event support',
  'Sales and promotion',
  'Personal services',
  'Others',
];

String? validateJobTitle(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 3) return 'Title needs at least 3 characters';
  if (length > 100) return 'Title is too long (100 max)';
  return null;
}

String? validateJobDescription(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 10) return 'Describe the job in at least 10 characters';
  if (length > 2000) return 'Description is too long (2000 max)';
  return null;
}

String? validateJobLocation(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 2) return 'Meetup location is required';
  if (length > 150) return 'Location is too long (150 max)';
  return null;
}

/// Minimum pay in pesos. Zero is allowed; negative or non-numbers are not.
String? validateMinPay(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Minimum pay is required';
  final amount = double.tryParse(text);
  if (amount == null) return 'Enter a number';
  if (amount < 0) return 'Pay cannot be negative';
  if (amount > 99999999) return 'Amount is too large';
  return null;
}

/// Philippine mobile: 09XXXXXXXXX or +639XXXXXXXXX. Same rule as 008 SQL.
String? validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Phone number is required';
  if (!RegExp(r'^(\+63|0)9[0-9]{9}$').hasMatch(text)) {
    return 'Use a mobile number like 09123456789';
  }
  return null;
}

/// A facebook.com or fb.com link. Same rule as 008 SQL.
String? validateFacebookUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Facebook link is required';
  final ok = RegExp(
    r'^https?://(www\.|m\.|web\.)?(facebook\.com|fb\.com)/.+',
    caseSensitive: false,
  ).hasMatch(text);
  if (!ok) return 'Paste your profile link, e.g. https://facebook.com/yourname';
  return null;
}

String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Full name is required';
  return null;
}