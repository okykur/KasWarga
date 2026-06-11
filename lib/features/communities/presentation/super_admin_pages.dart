import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/providers/app_providers.dart';

class CommunitiesPage extends ConsumerWidget {
  const CommunitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communitiesProvider);
    return PageScaffold(
      title: 'Semua Komunitas',
      subtitle:
          'Pantau tenant platform dan status operasional setiap komunitas.',
      child: communities.when(
        loading: () => const SizedBox(height: 360, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) => items.isEmpty
            ? const Card(
                child: SizedBox(
                  height: 260,
                  child: EmptyState(
                    title: 'Belum ada komunitas',
                    message: 'Komunitas baru akan muncul setelah dibuat user.',
                    icon: Icons.apartment_rounded,
                  ),
                ),
              )
            : Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final community = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFDDE9E2),
                        child: Icon(
                          Icons.apartment_rounded,
                          color: AppColors.forest,
                        ),
                      ),
                      title: Text(
                        community.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${community.type.label} · ${community.communityCode}\n'
                        '${community.city}, ${community.province}',
                      ),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(community.isActive ? 'Aktif' : 'Nonaktif'),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(profilesProvider);
    return PageScaffold(
      title: 'Semua Pengguna',
      subtitle:
          'Profil global platform. Role disimpan terpisah pada membership tiap komunitas.',
      child: users.when(
        loading: () => const SizedBox(height: 360, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) => Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final user = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 9,
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFDDE9E2),
                  child: Text(
                    user.fullName.isEmpty
                        ? '?'
                        : user.fullName[0].toUpperCase(),
                  ),
                ),
                title: Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${user.email} · '
                  '${PhoneNumberFormatter.maskPhoneNumber(user.phoneNumber)}',
                ),
                trailing: const Chip(label: Text('Akun Platform')),
              );
            },
          ),
        ),
      ),
    );
  }
}
