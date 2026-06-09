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
