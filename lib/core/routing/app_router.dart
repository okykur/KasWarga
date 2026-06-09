import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/presentation/announcements_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/bills/presentation/bills_pages.dart';
import '../../features/communities/presentation/super_admin_pages.dart';
import '../../features/dashboard/presentation/dashboard_pages.dart';
import '../../features/dues/presentation/dues_page.dart';
import '../../features/expenses/presentation/expenses_page.dart';
import '../../features/members/presentation/members_page.dart';
import '../../features/payment_accounts/presentation/payment_accounts_page.dart';
import '../../features/profile/presentation/profile_pages.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../widgets/app_shell.dart';
import 'role_route_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublic =
          path == '/login' || path == '/register' || path == '/forgot-password';

      if (auth.isLoading) return null;
      if (!auth.isAuthenticated) return isPublic ? null : '/login';

      final profile = auth.profile!;
      final home = roleHomePath(profile.role);
      if (isPublic) return home;
      if (AppConfig.isSupabaseConfigured &&
          profile.role == UserRole.member &&
          profile.communityId == null &&
          path != '/member/profile') {
        return '/member/profile';
      }

      if (!isRouteAllowedForRole(profile.role, path)) return home;
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Halaman tidak ditemukan: ${state.uri.path}'),
      ),
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (_, __, child) =>
            AppShell(role: UserRole.superAdmin, child: child),
        routes: [
          GoRoute(
            path: '/super-admin/dashboard',
            builder: (_, __) => const SuperAdminDashboardPage(),
          ),
          GoRoute(
            path: '/super-admin/communities',
            builder: (_, __) => const CommunitiesPage(),
          ),
          GoRoute(
            path: '/super-admin/users',
            builder: (_, __) => const UsersPage(),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(role: UserRole.admin, child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (_, __) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/admin/members',
            builder: (_, __) => const MembersPage(),
          ),
          GoRoute(
            path: '/admin/dues',
            builder: (_, __) => const DuesPage(),
          ),
          GoRoute(
            path: '/admin/bills',
            builder: (_, __) => const AdminBillsPage(),
          ),
          GoRoute(
            path: '/admin/payments',
            builder: (_, __) => const AdminBillsPage(verificationOnly: true),
          ),
          GoRoute(
            path: '/admin/payment-accounts',
            builder: (_, __) => const PaymentAccountsPage(),
          ),
          GoRoute(
            path: '/admin/expenses',
            builder: (_, __) => const ExpensesPage(),
          ),
          GoRoute(
            path: '/admin/announcements',
            builder: (_, __) => const AnnouncementsPage(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, __) => const ReportsPage(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) =>
            AppShell(role: UserRole.member, child: child),
        routes: [
          GoRoute(
            path: '/member/dashboard',
            builder: (_, __) => const MemberDashboardPage(),
          ),
          GoRoute(
            path: '/member/bills',
            builder: (_, __) => const MemberBillsPage(),
          ),
          GoRoute(
            path: '/member/bills/:id',
            builder: (_, state) =>
                MemberBillDetailPage(billId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/member/payment-history',
            builder: (_, __) => const MemberBillsPage(historyOnly: true),
          ),
          GoRoute(
            path: '/member/announcements',
            builder: (_, __) => const AnnouncementsPage(readOnly: true),
          ),
          GoRoute(
            path: '/member/profile',
            builder: (_, __) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});
