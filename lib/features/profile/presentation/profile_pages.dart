import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile!;
    return PageScaffold(
      title: 'Profil Saya',
      subtitle: 'Informasi akun yang digunakan untuk masuk ke KasWarga.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFDDE9E2),
                child: Icon(
                  Icons.person_rounded,
                  size: 42,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.fullName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                profile.role.label,
                style: const TextStyle(color: AppColors.muted),
              ),
              const Divider(height: 36),
              _ProfileRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: profile.email,
              ),
              _ProfileRow(
                icon: Icons.phone_outlined,
                label: 'Nomor Handphone',
                value: PhoneNumberFormatter.maskPhoneNumber(
                  profile.phoneNumber,
                ),
              ),
              _ProfileRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: profile.role.label,
              ),
              if (AppConfig.isSupabaseConfigured &&
                  profile.communityId == null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Akun Anda belum ditautkan ke komunitas. Hubungi admin komunitas agar tagihan dan pengumuman dapat diakses.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar dari Akun'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = profile.communityId ?? AppConstants.demoCommunityId;
    final communities = ref.watch(communitiesProvider);
    return PageScaffold(
      title: 'Pengaturan',
      subtitle: 'Informasi komunitas dan status koneksi aplikasi.',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: communities.when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(message: '$error'),
                data: (items) {
                  final community =
                      items.where((item) => item.id == communityId).firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Komunitas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      _ProfileRow(
                        icon: Icons.apartment_rounded,
                        label: 'Nama',
                        value: community?.name ?? '-',
                      ),
                      _ProfileRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value:
                            '${community?.address ?? '-'}, ${community?.city ?? '-'}',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Koneksi Backend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      AppConfig.isSupabaseConfigured
                          ? Icons.cloud_done_rounded
                          : Icons.science_rounded,
                      color: AppConfig.isSupabaseConfigured
                          ? AppColors.success
                          : AppColors.amber,
                    ),
                    title: Text(
                      AppConfig.isSupabaseConfigured
                          ? 'Supabase terhubung'
                          : 'Mode demo lokal',
                    ),
                    subtitle: const Text(
                      'URL dan anon key dibaca melalui --dart-define, bukan hardcode.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.forest),
        title: Text(label, style: const TextStyle(color: AppColors.muted)),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
