import '../constants/app_constants.dart';

String roleHomePath(UserRole role) => switch (role) {
      UserRole.superAdmin => '/super-admin/dashboard',
      UserRole.admin => '/admin/dashboard',
      UserRole.member => '/member/dashboard',
    };

bool isRouteAllowedForRole(UserRole role, String path) {
  final prefix = switch (role) {
    UserRole.superAdmin => '/super-admin',
    UserRole.admin => '/admin',
    UserRole.member => '/member',
  };
  return path.startsWith(prefix);
}

String membershipHomePath(MembershipRole role) =>
    role.canManage ? '/admin/dashboard' : '/member/dashboard';

bool isRouteAllowedForMembership(MembershipRole role, String path) {
  if (path.startsWith('/admin')) return role.canManage;
  if (path.startsWith('/member')) return true;
  return path == '/onboarding' ||
      path == '/select-community' ||
      path == '/create-community' ||
      path == '/join-community' ||
      path == '/accept-invitation';
}
