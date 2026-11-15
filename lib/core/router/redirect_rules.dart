import '../../features/auth/models/profile.dart';

const _authPaths = {'/login', '/signup', '/verify'};
const _statusPaths = {'/pending', '/rejected', '/suspended'};

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
  required Profile? profile,
  required String location,
}) {
  if (!loggedIn) {
    return _authPaths.contains(location) ? null : '/login';
  }
  if (profileLoading || profile == null) return null;

  final target = homeFor(profile);

  if (profile.status != 'verified') {
    return location == target ? null : target;
  }
  if (_authPaths.contains(location) || _statusPaths.contains(location)) {
    return target;
  }
  if (location.startsWith('/admin') && profile.role != 'admin') {
    return '/home';
  }
  return null;
}