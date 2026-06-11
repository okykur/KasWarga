import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class SuperAdminDashboardPage extends ConsumerWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communitiesProvider);
    final profiles = ref.watch(profilesProvider);
    return PageScaffold(
      title: 'Dashboard Platform',
      subtitle: 'Pantau pertumbuhan dan kesehatan ekosistem KasWarga.',
      child: communities.when(
        loading: () => const SizedBox(height: 420, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (communityItems) => profiles.when(
          loading: () => const SizedBox(height: 420, child: LoadingView()),
          error: (error, _) => ErrorView(message: '$error'),
          data: (profileItems) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricGrid(
                  cards: [
                    DashboardCard(
                      title: 'Total Komunitas',
                      value: '${communityItems.length}',
                      icon: Icons.apartment_rounded,
                    ),
                    DashboardCard(
                      title: 'Komunitas Aktif',
                      value:
                          '${communityItems.where((item) => item.isActive).length}',
                      icon: Icons.domain_verification_rounded,
                      accent: AppColors.success,
                    ),
                    DashboardCard(
                      title: 'Total Pengguna',
                      value: '${profileItems.length}',
                      icon: Icons.groups_rounded,
                      accent: AppColors.amber,
                    ),
                    DashboardCard(
                      title: 'Akun Terdaftar',
                      value: '${profileItems.length}',
                      icon: Icons.manage_accounts_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _GrowthPanel(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile!;
    final communityId = auth.selectedCommunityId!;
    final members = ref.watch(membersProvider(communityId));
    final bills = ref.watch(
      billsProvider(
        (communityId: communityId, memberId: null, status: null),
      ),
    );
    final summary = ref.watch(cashSummaryProvider(communityId));
    final accounts = ref.watch(
      paymentAccountsProvider(
        (communityId: communityId, activeOnly: false),
      ),
    );

    return PageScaffold(
      title: 'Selamat pagi, ${profile.fullName.split(' ').first}',
      subtitle: 'Berikut keadaan kas dan iuran komunitas hari ini.',
      child: summary.when(
        loading: () => const SizedBox(height: 420, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (cash) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetricGrid(
              cards: [
                DashboardCard(
                  title: 'Total Anggota',
                  value: members.valueOrNull?.length.toString() ?? '-',
                  icon: Icons.groups_2_rounded,
                ),
                DashboardCard(
                  title: 'Anggota Aktif',
                  value:
                      '${members.valueOrNull?.where((item) => item.status == 'active').length ?? 0}',
                  icon: Icons.how_to_reg_rounded,
                  accent: AppColors.success,
                ),
                DashboardCard(
                  title: 'Total Iuran Lunas',
                  value: AppFormatters.rupiah(cash.totalPaid),
                  icon: Icons.task_alt_rounded,
                  accent: AppColors.success,
                ),
                DashboardCard(
                  title: 'Total Belum Lunas',
                  value: AppFormatters.rupiah(cash.totalUnpaid),
                  icon: Icons.pending_actions_rounded,
                  accent: AppColors.amber,
                ),
                DashboardCard(
                  title: 'Menunggu Verifikasi',
                  value:
                      '${bills.valueOrNull?.where((b) => b.status == BillStatus.waitingVerification).length ?? 0}',
                  icon: Icons.hourglass_top_rounded,
                  accent: AppColors.amber,
                ),
                DashboardCard(
                  title: 'Total Pengeluaran',
                  value: AppFormatters.rupiah(cash.totalExpenses),
                  icon: Icons.payments_rounded,
                  accent: AppColors.danger,
                ),
                DashboardCard(
                  title: 'Saldo Kas',
                  value: AppFormatters.rupiah(cash.balance),
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Pembayaran perlu diperiksa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _WaitingPayments(
              bills: bills.valueOrNull
                      ?.where(
                        (bill) => bill.status == BillStatus.waitingVerification,
                      )
                      .toList() ??
                  const [],
            ),
            const SizedBox(height: 24),
            Text(
              'Ringkasan per rekening tujuan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _AccountPaymentSummary(
              accounts: accounts.valueOrNull ?? const [],
              bills: bills.valueOrNull ?? const [],
            ),
          ],
        ),
      ),
    );
  }
}

class MemberDashboardPage extends ConsumerWidget {
  const MemberDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile!;
    final communityId = auth.selectedCommunityId!;
    return FutureBuilder<String?>(
      future: ref.read(appRepositoryProvider).getMemberIdForUser(
            profile.id,
            communityId: communityId,
          ),
      builder: (context, memberSnapshot) {
        if (memberSnapshot.connectionState == ConnectionState.waiting) {
          return const PageScaffold(
            title: 'Beranda',
            subtitle: 'Menyiapkan data warga...',
            child: SizedBox(height: 360, child: LoadingView()),
          );
        }
        if (memberSnapshot.data == null && AppConfig.isSupabaseConfigured) {
          return const PageScaffold(
            title: 'Beranda',
            subtitle: 'Akun belum terhubung ke data anggota.',
            child: Card(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  title: 'Data anggota belum ditautkan',
                  message:
                      'Hubungi admin komunitas agar akun login Anda dihubungkan ke data anggota.',
                  icon: Icons.link_off_rounded,
                ),
              ),
            ),
          );
        }
        final memberId = memberSnapshot.data;
        if (memberId == null) {
          return const PageScaffold(
            title: 'Beranda',
            subtitle: 'Data anggota belum tersedia.',
            child: SizedBox(
              height: 280,
              child: EmptyState(
                title: 'Detail warga belum lengkap',
                message: 'Hubungi admin untuk melengkapi data keanggotaan.',
              ),
            ),
          );
        }
        final bills = ref.watch(
          billsProvider(
            (communityId: communityId, memberId: memberId, status: null),
          ),
        );
        final summary = ref.watch(cashSummaryProvider(communityId));
        final accounts = ref.watch(
          paymentAccountsProvider(
            (communityId: communityId, activeOnly: true),
          ),
        );
        final announcements = ref.watch(announcementsProvider(communityId));
        return PageScaffold(
          title: 'Halo, ${profile.fullName.split(' ').first}',
          subtitle: AppFormatters.monthYear(DateTime.now()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bills.when(
                loading: () =>
                    const SizedBox(height: 180, child: LoadingView()),
                error: (error, _) => ErrorView(message: '$error'),
                data: (items) {
                  final unpaid = items.where(
                    (item) => item.status != BillStatus.paid,
                  );
                  final total =
                      unpaid.fold<double>(0, (sum, item) => sum + item.amount);
                  return _MemberHero(
                    totalUnpaid: total,
                    currentStatus:
                        items.isEmpty ? BillStatus.unpaid : items.first.status,
                  );
                },
              ),
              const SizedBox(height: 20),
              _MetricGrid(
                cards: [
                  DashboardCard(
                    title: 'Saldo Kas Komunitas',
                    value: summary.valueOrNull == null
                        ? '-'
                        : AppFormatters.rupiah(summary.valueOrNull!.balance),
                    icon: Icons.savings_rounded,
                  ),
                  DashboardCard(
                    title: 'Rekening Utama',
                    value: accounts.valueOrNull
                            ?.where((item) => item.isDefault)
                            .map((item) => item.bankName)
                            .firstOrNull ??
                        '-',
                    icon: Icons.account_balance_rounded,
                    accent: AppColors.amber,
                  ),
                ],
                maxColumns: 2,
              ),
              const SizedBox(height: 24),
              Text(
                'Pengumuman terbaru',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _AnnouncementPreview(
                item: announcements.valueOrNull?.firstOrNull,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards, this.maxColumns = 4});
  final List<Widget> cards;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? maxColumns
            : width >= 620
                ? maxColumns.clamp(1, 2)
                : 1;
        final itemWidth = (width - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, height: 180, child: card),
          ],
        );
      },
    );
  }
}

class _WaitingPayments extends StatelessWidget {
  const _WaitingPayments({required this.bills});
  final List<Bill> bills;

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: EmptyState(
            title: 'Semua sudah diperiksa',
            message: 'Belum ada pembayaran yang menunggu verifikasi.',
            icon: Icons.verified_rounded,
          ),
        ),
      );
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bills.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final bill = bills[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF1D6),
              child: Icon(Icons.receipt_rounded, color: AppColors.amber),
            ),
            title: Text(bill.memberName ?? 'Warga'),
            subtitle: Text(bill.title ?? 'Iuran'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.rupiah(bill.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                StatusBadge(status: bill.status),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccountPaymentSummary extends StatelessWidget {
  const _AccountPaymentSummary({
    required this.accounts,
    required this.bills,
  });

  final List<PaymentAccount> accounts;
  final List<Bill> bills;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 150,
          child: EmptyState(
            title: 'Belum ada rekening tujuan',
            message: 'Tambahkan rekening untuk melihat ringkasan transfer.',
            icon: Icons.account_balance_outlined,
          ),
        ),
      );
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final account = accounts[index];
          final paid = bills.where(
            (bill) =>
                bill.status == BillStatus.paid &&
                bill.selectedPaymentAccountId == account.id,
          );
          final total = paid.fold<double>(0, (sum, bill) => sum + bill.amount);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.forest,
            ),
            title: Text(
              '${account.bankName} • ${account.accountNumber}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${paid.length} pembayaran lunas'),
            trailing: Text(
              AppFormatters.rupiah(total),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
    );
  }
}

class _GrowthPanel extends StatelessWidget {
  const _GrowthPanel();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pertumbuhan komunitas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Statistik bulanan akan terisi dari data komunitas production.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final height in [
                      60.0,
                      90.0,
                      76.0,
                      120.0,
                      145.0,
                      170.0
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: height == 170
                                  ? AppColors.amber
                                  : AppColors.forest.withValues(alpha: .16),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _MemberHero extends StatelessWidget {
  const _MemberHero({
    required this.totalUnpaid,
    required this.currentStatus,
  });
  final double totalUnpaid;
  final BillStatus currentStatus;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24174A3A),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 18,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total tagihan belum lunas',
                  style: TextStyle(color: Color(0xFFD5E4DC)),
                ),
                const SizedBox(height: 8),
                Text(
                  AppFormatters.rupiah(totalUnpaid),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            StatusBadge(status: currentStatus),
          ],
        ),
      );
}

class _AnnouncementPreview extends StatelessWidget {
  const _AnnouncementPreview({this.item});
  final Announcement? item;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const Card(
        child: SizedBox(
          height: 160,
          child: EmptyState(
            title: 'Belum ada pengumuman',
            message: 'Kabar terbaru komunitas akan tampil di sini.',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFF1D6),
              child: Icon(Icons.campaign_rounded, color: AppColors.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item!.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (item!.isPinned)
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 18,
                          color: AppColors.amber,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item!.content,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
