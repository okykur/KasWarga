import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';

class CommunitiesPage extends ConsumerWidget {
  const CommunitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communitiesProvider);
    return PageScaffold(
      title: 'Semua Komunitas',
      subtitle: 'Buat, perbarui, dan nonaktifkan komunitas di platform.',
      action: AppButton(
        label: 'Buat Komunitas',
        icon: Icons.add_business_rounded,
        onPressed: () => _showForm(context, ref),
      ),
      child: communities.when(
        loading: () => const SizedBox(height: 360, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) => Card(
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
                  child: Icon(Icons.apartment_rounded, color: AppColors.forest),
                ),
                title: Text(
                  community.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${community.address}, ${community.city}, ${community.province} ${community.postalCode}',
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(community.isActive ? 'Aktif' : 'Nonaktif'),
                    ),
                    IconButton(
                      onPressed: () =>
                          _showForm(context, ref, community: community),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    Community? community,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CommunityForm(community: community),
    );
    if (saved == true) ref.invalidate(communitiesProvider);
  }
}

class _CommunityForm extends ConsumerStatefulWidget {
  const _CommunityForm({this.community});
  final Community? community;

  @override
  ConsumerState<_CommunityForm> createState() => _CommunityFormState();
}

class _CommunityFormState extends ConsumerState<_CommunityForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _postalCode;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.community;
    _name = TextEditingController(text: item?.name);
    _address = TextEditingController(text: item?.address);
    _city = TextEditingController(text: item?.city);
    _province = TextEditingController(text: item?.province);
    _postalCode = TextEditingController(text: item?.postalCode);
    _active = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.community == null ? 'Buat Komunitas' : 'Edit Komunitas',
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Nama Komunitas',
                    controller: _name,
                    validator: (value) =>
                        Validators.required(value, field: 'Nama komunitas'),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Alamat',
                    controller: _address,
                    maxLines: 2,
                    validator: (value) =>
                        Validators.required(value, field: 'Alamat'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Kota/Kabupaten',
                          controller: _city,
                          validator: (value) =>
                              Validators.required(value, field: 'Kota'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Provinsi',
                          controller: _province,
                          validator: (value) =>
                              Validators.required(value, field: 'Provinsi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Kode Pos',
                    controller: _postalCode,
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        Validators.required(value, field: 'Kode pos'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Komunitas aktif'),
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _saving = true);
                    await ref.read(appRepositoryProvider).saveCommunity(
                          id: widget.community?.id,
                          name: _name.text,
                          address: _address.text,
                          city: _city.text,
                          province: _province.text,
                          postalCode: _postalCode.text,
                          isActive: _active,
                        );
                    if (mounted) Navigator.pop(context, true);
                  },
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      );
}
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(profilesProvider);
    final communities = ref.watch(communitiesProvider);
    return PageScaffold(
      title: 'Semua Pengguna',
      subtitle: 'Kelola role dan penempatan komunitas pengguna.',
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
                  child: Text(user.fullName[0].toUpperCase()),
                ),
                title: Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${user.email} • ${PhoneNumberFormatter.maskPhoneNumber(user.phoneNumber)}',
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(user.role.label)),
                    IconButton(
                      tooltip: 'Ubah role',
                      onPressed: () async {
                        final saved = await showDialog<bool>(
                          context: context,
                          builder: (_) => _UserRoleForm(
                            user: user,
                            communities: communities.valueOrNull ?? const [],
                          ),
                        );
                        if (saved == true) ref.invalidate(profilesProvider);
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserRoleForm extends ConsumerStatefulWidget {
  const _UserRoleForm({required this.user, required this.communities});
  final UserProfile user;
  final List<Community> communities;

  @override
  ConsumerState<_UserRoleForm> createState() => _UserRoleFormState();
}

class _UserRoleFormState extends ConsumerState<_UserRoleForm> {
  late UserRole _role;
  String? _communityId;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _communityId = widget.user.communityId;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Atur Role Pengguna'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDropdown<UserRole>(
                label: 'Role',
                value: _role,
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: (value) => setState(() {
                  _role = value ?? _role;
                  if (_role == UserRole.superAdmin) _communityId = null;
                }),
              ),
              if (_role != UserRole.superAdmin) ...[
                const SizedBox(height: 14),
                AppDropdown<String>(
                  label: 'Komunitas',
                  value: _communityId,
                  items: [
                    for (final community in widget.communities)
                      DropdownMenuItem(
                        value: community.id,
                        child: Text(community.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _communityId = value),
                  validator: (value) =>
                      value == null ? 'Komunitas wajib dipilih.' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (_role != UserRole.superAdmin && _communityId == null) return;
              await ref.read(appRepositoryProvider).updateProfileRole(
                    profileId: widget.user.id,
                    role: _role,
                    communityId: _communityId,
                  );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      );
}
