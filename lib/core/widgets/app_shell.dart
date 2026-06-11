import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class AppNavItem {
  const AppNavItem(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

const superAdminNavItems = [
  AppNavItem('Dashboard', '/super-admin/dashboard', Icons.grid_view_rounded),
  AppNavItem('Komunitas', '/super-admin/communities', Icons.apartment_rounded),
  AppNavItem('Pengguna', '/super-admin/users', Icons.manage_accounts_rounded),
  AppNavItem(
    'Subscription',
    '/super-admin/subscriptions',
    Icons.workspace_premium_rounded,
  ),
];

const adminNavItems = [
  AppNavItem('Dashboard', '/admin/dashboard', Icons.grid_view_rounded),
  AppNavItem('Undangan', '/admin/invitations', Icons.forward_to_inbox_rounded),
  AppNavItem(
    'Permintaan',
    '/admin/join-requests',
    Icons.how_to_reg_rounded,
  ),
  AppNavItem('Anggota', '/admin/members', Icons.groups_2_rounded),
  AppNavItem('Iuran', '/admin/dues', Icons.receipt_long_rounded),
  AppNavItem('Tagihan', '/admin/bills', Icons.fact_check_rounded),
  AppNavItem('Verifikasi', '/admin/payments', Icons.verified_rounded),
  AppNavItem(
    'Rekening',
    '/admin/payment-accounts',
    Icons.account_balance_rounded,
  ),
  AppNavItem('Pengeluaran', '/admin/expenses', Icons.payments_rounded),
  AppNavItem('Pengumuman', '/admin/announcements', Icons.campaign_rounded),
  AppNavItem('Laporan', '/admin/reports', Icons.bar_chart_rounded),
  AppNavItem(
    'Pengaturan',
    '/admin/community-settings',
    Icons.settings_rounded,
  ),
];

const memberNavItems = [
  AppNavItem('Beranda', '/member/dashboard', Icons.home_rounded),
  AppNavItem('Tagihan', '/member/bills', Icons.receipt_long_rounded),
  AppNavItem('Riwayat', '/member/payment-history', Icons.history_rounded),
  AppNavItem('Pengumuman', '/member/announcements', Icons.campaign_rounded),
  AppNavItem('Profil', '/member/profile', Icons.person_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.role,
    required this.child,
  });

  final UserRole role;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final items = switch (role) {
      UserRole.superAdmin => superAdminNavItems,
      UserRole.admin => adminNavItems,
      UserRole.member => memberNavItems,
    };
    final selectedIndex = _selectedIndex(items, location);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final profile = ref.watch(authControllerProvider).profile;
    final auth = ref.watch(authControllerProvider);
    final roleLabel = auth.isPlatformSuperAdmin && role == UserRole.superAdmin
        ? 'Super Admin Platform'
        : auth.membershipRole?.label ?? role.label;

    if (role == UserRole.member && !isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: const _ShellBrand(compact: true),
          backgroundColor: AppColors.cream,
          actions: [
            if (auth.memberships.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: CommunitySwitcher(compact: true),
              ),
            IconButton(
              tooltip: 'Keluar',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex.clamp(0, items.length - 1),
          onDestinationSelected: (index) => context.go(items[index].path),
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(
              child: _Sidebar(
                items: items,
                selectedIndex: selectedIndex,
                profileName: profile?.fullName ?? '',
                roleLabel: roleLabel,
              ),
            ),
      appBar: isDesktop
          ? null
          : AppBar(
              title: const _ShellBrand(compact: true),
              backgroundColor: AppColors.cream,
            ),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 264,
              child: _Sidebar(
                items: items,
                selectedIndex: selectedIndex,
                profileName: profile?.fullName ?? '',
                roleLabel: roleLabel,
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(List<AppNavItem> items, String location) {
    final index = items.indexWhere(
      (item) =>
          location == item.path ||
          (item.path != '/member/bills' &&
              location.startsWith('${item.path}/')),
    );
    return index < 0 ? 0 : index;
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.profileName,
    required this.roleLabel,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final String profileName;
  final String roleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: AppColors.forestDark,
      child: SafeArea(
        child: Column(
          children: [
            if (ref.watch(authControllerProvider).memberships.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: CommunitySwitcher(),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: _ShellBrand(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = selectedIndex == index;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: Colors.white.withValues(alpha: .12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      item.icon,
                      color: selected ? Colors.white : const Color(0xFFACC1B8),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFFD5E4DC),
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                        Navigator.pop(context);
                      }
                      context.go(item.path);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.amber,
                      child: Icon(Icons.person_rounded, color: AppColors.ink),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            roleLabel,
                            style: const TextStyle(
                              color: Color(0xFFACC1B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Keluar',
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunitySwitcher extends ConsumerWidget {
  const CommunitySwitcher({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.memberships.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Ganti komunitas',
      onSelected: (communityId) {
        if (communityId == '__select__') {
          context.go('/select-community');
          return;
        }
        ref.read(authControllerProvider.notifier).selectCommunity(communityId);
        final membership = ref
            .read(authControllerProvider)
            .memberships
            .firstWhere((item) => item.communityId == communityId);
        context.go(
          membership.canManage ? '/admin/dashboard' : '/member/dashboard',
        );
      },
      itemBuilder: (_) => [
        for (final membership in auth.memberships)
          PopupMenuItem(
            value: membership.communityId,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                membership.communityId == auth.selectedCommunityId
                    ? Icons.check_circle_rounded
                    : Icons.apartment_rounded,
                color: AppColors.forest,
              ),
              title: Text(membership.community.name),
              subtitle: Text(membership.role.label),
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '__select__',
          child: Text('Lihat semua komunitas'),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: compact
              ? AppColors.forest.withValues(alpha: .08)
              : Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 18,
              color: compact ? AppColors.forest : Colors.white,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 130 : 180),
              child: Text(
                auth.selectedMembership?.community.name ?? 'Pilih komunitas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: compact ? AppColors.ink : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              color: compact ? AppColors.ink : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellBrand extends StatelessWidget {
  const _ShellBrand({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: compact ? AppColors.forest : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.holiday_village_rounded,
              color: compact ? Colors.white : AppColors.forest,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: TextStyle(
              color: compact ? AppColors.ink : Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 14,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                    if (action != null) action!,
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      );
}
