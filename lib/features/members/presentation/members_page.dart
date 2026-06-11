import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String _search = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final communityId = ref.watch(authControllerProvider).selectedCommunityId!;
    final members = ref.watch(membersProvider(communityId));
    return PageScaffold(
      title: 'Anggota Warga',
      subtitle: 'Kelola data rumah tangga dan tautkan dengan akun warga.',
      action: AppButton(
        label: 'Undang Anggota',
        icon: Icons.person_add_alt_1_rounded,
        onPressed: () => context.go('/admin/invitations'),
      ),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Cari anggota',
                      hint: 'Nama, nomor HP, blok, atau nomor rumah',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (value) =>
                          setState(() => _search = value.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 170,
                    child: AppDropdown<String>(
                      label: 'Status',
                      value: _status,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Semua'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Aktif'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Nonaktif'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'all'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          members.when(
            loading: () => const SizedBox(height: 360, child: LoadingView()),
            error: (error, _) => ErrorView(message: '$error'),
            data: (items) {
              final filtered = items.where((member) {
                final haystack =
                    '${member.fullName} ${member.phoneNumber} ${member.houseBlock} ${member.houseNumber}'
                        .toLowerCase();
                return haystack.contains(_search) &&
                    (_status == 'all' || member.status == _status);
              }).toList();
              if (filtered.isEmpty) {
                return const Card(
                  child: SizedBox(
                    height: 300,
                    child: EmptyState(
                      title: 'Anggota tidak ditemukan',
                      message: 'Ubah filter atau tambahkan anggota baru.',
                      icon: Icons.person_search_rounded,
                    ),
                  ),
                );
              }
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final member = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: member.status == 'active'
                            ? const Color(0xFFDDE9E2)
                            : const Color(0xFFE8E7E3),
                        child: Text(
                          member.fullName.isEmpty
                              ? '?'
                              : member.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Blok ${member.houseBlock}-${member.houseNumber} • ${member.phoneNumber} • ${member.familyCount} anggota keluarga',
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            label: Text(
                              member.status == 'active' ? 'Aktif' : 'Nonaktif',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _showForm(
                              context,
                              communityId,
                              member: member,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    String communityId, {
    CommunityMember? member,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MemberForm(
        communityId: communityId,
        member: member,
      ),
    );
    if (saved == true) ref.invalidate(membersProvider);
  }
}

class _MemberForm extends ConsumerStatefulWidget {
  const _MemberForm({
    required this.communityId,
    this.member,
  });
  final String communityId;
  final CommunityMember? member;

  @override
  ConsumerState<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends ConsumerState<_MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _block;
  late final TextEditingController _number;
  late final TextEditingController _family;
  late String _status;
  String? _userId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _name = TextEditingController(text: member?.fullName);
    _phone = TextEditingController(text: member?.phoneNumber);
    _block = TextEditingController(text: member?.houseBlock);
    _number = TextEditingController(text: member?.houseNumber);
    _family = TextEditingController(text: '${member?.familyCount ?? 1}');
    _status = member?.status ?? 'active';
    _userId = member?.userId;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _block.dispose();
    _number.dispose();
    _family.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.member == null ? 'Tambah Anggota' : 'Edit Anggota'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Nama Lengkap',
                    controller: _name,
                    validator: (value) =>
                        Validators.required(value, field: 'Nama lengkap'),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Nomor Handphone',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Blok',
                          controller: _block,
                          validator: (value) =>
                              Validators.required(value, field: 'Blok'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Nomor Rumah',
                          controller: _number,
                          validator: (value) => Validators.required(
                            value,
                            field: 'Nomor rumah',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Jumlah Anggota Keluarga',
                    controller: _family,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      return parsed == null || parsed < 1
                          ? 'Jumlah keluarga minimal 1.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppDropdown<String>(
                    label: 'Status',
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Nonaktif'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'active'),
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
                    try {
                      final phone =
                          PhoneNumberFormatter.normalizeIndonesianPhoneNumber(
                        _phone.text,
                      );
                      await ref.read(appRepositoryProvider).saveMember(
                            id: widget.member?.id,
                            communityId: widget.communityId,
                            userId: _userId,
                            fullName: _name.text,
                            phoneNumber: phone,
                            block: _block.text,
                            houseNumber: _number.text,
                            familyCount: int.parse(_family.text),
                            status: _status,
                          );
                      if (!mounted) return;
                      Navigator.pop(this.context, true);
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Gagal menyimpan: $error')),
                        );
                        setState(() => _saving = false);
                      }
                    }
                  },
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      );
}
