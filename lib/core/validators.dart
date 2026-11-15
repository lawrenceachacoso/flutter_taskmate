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