import '../../features/auth/models/profile.dart';

const _authPaths = {'/login', '/signup', '/verify'};
const _statusPaths = {'/pending', '/rejected', '/suspended'};
const _problemPath = '/account-problem';

String homeFor(Profile profile) {
  switch (profile.status) {
    case 'verified':
      return profile.role == 'admin' ? '/admin' : '/home';
    case 'rejected':
      return '/rejected';
    case 'suspended':
      return '/suspended';
    default:
      return '/pending';
  }
}

String? computeRedirect({
  required bool loggedIn,
  required bool profileLoading,
  required bool profileFailed,
  required Profile? profile,
  required String location,
}) {
  if (!loggedIn) {
    return _authPaths.contains(location) ? null : '/login';
  }

  // Logged in but the profile could not be loaded (error, or no row found).
  // Show a visible problem screen instead of leaving the user stuck.
  if (profileFailed || (!profileLoading && profile == null)) {
    return location == _problemPath ? null : _problemPath;
  }
  if (profileLoading || profile == null) return null;

  final target = homeFor(profile);

  if (profile.status != 'verified') {
    return location == target ? null : target;
  }
  if (_authPaths.contains(location) ||
      _statusPaths.contains(location) ||
      location == _problemPath) {
    return target;
  }
  if (location.startsWith('/admin') && profile.role != 'admin') {
    return '/home';
  }
  return null;
}
