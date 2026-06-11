import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/role_route_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/community_code.dart';
import '../../../core/utils/phone_number_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/services/app_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_pages.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) => AuthBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                children: [
                  const Icon(
                    Icons.holiday_village_rounded,
                    size: 54,
                    color: AppColors.forest,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Selamat datang di KasWarga',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Buat komunitas warga Anda sendiri atau bergabung ke komunitas yang sudah ada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                  const SizedBox(height: 34),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _OnboardingChoice(
                        title: 'Buat Komunitas Baru',
                        description:
                            'Mulai cluster, RT/RW, sekolah, masjid, atau organisasi Anda.',
                        icon: Icons.add_business_rounded,
                        onTap: () => context.go('/create-community'),
                      ),
                      _OnboardingChoice(
                        title: 'Gabung dengan Kode',
                        description:
                            'Masukkan kode yang diberikan pengurus komunitas.',
                        icon: Icons.password_rounded,
                        onTap: () => context.go('/join-community'),
                      ),
                      _OnboardingChoice(
                        title: 'Saya Punya Link Undangan',
                        description:
                            'Buka tautan undangan yang dikirim oleh admin.',
                        icon: Icons.mark_email_read_rounded,
                        onTap: () => context.go('/accept-invitation'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _OnboardingChoice extends StatelessWidget {
  const _OnboardingChoice({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 286,
        height: 230,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.forest.withValues(alpha: .1),
                    child: Icon(icon, color: AppColors.forest),
                  ),
                  const Spacer(),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class SelectCommunityPage extends ConsumerWidget {
  const SelectCommunityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih komunitas',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih ruang kerja yang ingin dibuka. Anda dapat menggantinya lagi dari sidebar.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    for (final membership in auth.memberships)
                      Card(
                        color: AppColors.cream,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.forest,
                            child: Icon(
                              Icons.apartment_rounded,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            membership.community.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${membership.role.label} · ${membership.community.city}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_rounded),
                          onTap: () {
                            ref
                                .read(authControllerProvider.notifier)
                                .selectCommunity(membership.communityId);
                            context.go(membershipHomePath(membership.role));
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/join-community'),
                            icon: const Icon(Icons.group_add_rounded),
                            label: const Text('Gabung Komunitas'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.go('/create-community'),
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Buat Komunitas'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key});

  @override
  ConsumerState<CreateCommunityPage> createState() =>
      _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();
  final _code = TextEditingController();
  CommunityType _type = CommunityType.cluster;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _city,
      _province,
      _postalCode,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authControllerProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final allowed = await ref
          .read(appRepositoryProvider)
          .canCreateCommunity(auth.profile!.id);
      if (!allowed) {
        throw const TenantException(
          'Batas pembuatan komunitas pada plan Anda sudah tercapai.',
        );
      }
      final membership = await ref.read(appRepositoryProvider).createCommunity(
            userId: auth.profile!.id,
            fullName: auth.profile!.fullName,
            phoneNumber: auth.profile!.phoneNumber,
            name: _name.text,
            type: _type,
            address: _address.text,
            city: _city.text,
            province: _province.text,
            postalCode: _postalCode.text,
            communityCode: _code.text,
          );
      await ref
          .read(authControllerProvider.notifier)
          .refreshTenancy(preferredCommunityId: membership.communityId);
      if (mounted) context.go('/admin/dashboard');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buat Komunitas Baru',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 22),
                        AppTextField(
                          label: 'Nama Komunitas',
                          controller: _name,
                          onChanged: (value) {
                            if (_code.text.isEmpty ||
                                CommunityCode.isValid(_code.text)) {
                              _code.text = CommunityCode.generate(value);
                            }
                            setState(() {});
                          },
                          validator: (value) => Validators.required(
                            value,
                            field: 'Nama komunitas',
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppDropdown<CommunityType>(
                          label: 'Tipe Komunitas',
                          value: _type,
                          items: [
                            for (final type in CommunityType.values)
                              DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _type = value ?? _type),
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
                                validator: (value) => Validators.required(
                                  value,
                                  field: 'Provinsi',
                                ),
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
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Kode Komunitas',
                          controller: _code,
                          validator: CommunityCode.validationMessage,
                          onChanged: (_) => setState(() {}),
                          suffixIcon: IconButton(
                            tooltip: 'Generate ulang',
                            onPressed: () {
                              _code.text = CommunityCode.generate(_name.text);
                              setState(() {});
                            },
                            icon: const Icon(Icons.autorenew_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Preview: ${CommunityCode.normalize(_code.text)}',
                            style: const TextStyle(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                        const SizedBox(height: 22),
                        AppButton(
                          label: 'Buat Komunitas',
                          onPressed: _submit,
                          isLoading: _saving,
                          expand: true,
                          icon: Icons.rocket_launch_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class JoinCommunityPage extends ConsumerStatefulWidget {
  const JoinCommunityPage({super.key});

  @override
  ConsumerState<JoinCommunityPage> createState() => _JoinCommunityPageState();
}

class _JoinCommunityPageState extends ConsumerState<JoinCommunityPage> {
  final _code = TextEditingController();
  final _note = TextEditingController();
  Community? _preview;
  String? _message;
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (!CommunityCode.isValid(_code.text)) {
      setState(() => _message = CommunityCode.validationMessage(_code.text));
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    final community =
        await ref.read(appRepositoryProvider).findCommunityByCode(_code.text);
    if (mounted) {
      setState(() {
        _preview = community;
        _message = community == null ? 'Kode komunitas tidak ditemukan.' : null;
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      context.go('/login?next=/join-community');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref.read(appRepositoryProvider).joinCommunityByCode(
            userId: auth.profile!.id,
            code: _code.text,
            note: _note.text,
          );
      await ref.read(authControllerProvider.notifier).refreshTenancy();
      if (!mounted) return;
      if (result == 'pending') {
        setState(() {
          _message =
              'Permintaan bergabung berhasil dikirim. Mohon menunggu persetujuan admin.';
          _preview = null;
        });
      } else {
        final memberships = ref.read(authControllerProvider).memberships;
        final joined = memberships.firstWhere(
          (item) =>
              item.community.communityCode ==
              CommunityCode.normalize(_code.text),
        );
        ref
            .read(authControllerProvider.notifier)
            .selectCommunity(joined.communityId);
        context.go('/member/dashboard');
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gabung Komunitas',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Masukkan kode komunitas dari pengurus Anda.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 22),
                      AppTextField(
                        label: 'Kode Komunitas',
                        controller: _code,
                        suffixIcon: IconButton(
                          onPressed: _loading ? null : _find,
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                      if (_preview != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _preview!.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_preview!.type.label} · ${_preview!.city}',
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                label: 'Catatan untuk admin (opsional)',
                                controller: _note,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 14),
                              AppButton(
                                label: _preview!.requireAdminApproval
                                    ? 'Kirim Permintaan'
                                    : 'Gabung Sekarang',
                                onPressed: _join,
                                isLoading: _loading,
                                expand: true,
                                icon: Icons.group_add_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _message!,
                          style: TextStyle(
                            color: _message!.contains('berhasil')
                                ? AppColors.success
                                : AppColors.danger,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (_preview == null) ...[
                        const SizedBox(height: 18),
                        AppButton(
                          label: 'Cari Komunitas',
                          onPressed: _find,
                          isLoading: _loading,
                          expand: true,
                          icon: Icons.search_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class InvitationsPage extends ConsumerStatefulWidget {
  const InvitationsPage({super.key});

  @override
  ConsumerState<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends ConsumerState<InvitationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  MembershipRole _role = MembershipRole.member;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final communityId = auth.selectedCommunityId!;
    final invitations = ref.watch(invitationsProvider(communityId));
    return PageScaffold(
      title: 'Undangan Komunitas',
      subtitle:
          'Undang warga dan pengurus. Link dapat disalin jika email provider belum aktif.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 280,
                      child: AppTextField(
                        label: 'Email',
                        controller: _email,
                        validator: Validators.email,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: AppTextField(
                        label: 'Nama Lengkap (opsional)',
                        controller: _name,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: AppTextField(
                        label: 'Nomor HP (opsional)',
                        controller: _phone,
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: AppDropdown<MembershipRole>(
                        label: 'Role',
                        value: _role,
                        items: [
                          for (final role in <MembershipRole>[
                            if (auth.membershipRole == MembershipRole.owner)
                              MembershipRole.admin,
                            MembershipRole.treasurer,
                            MembershipRole.member,
                          ])
                            DropdownMenuItem(
                              value: role,
                              child: Text(role.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _role = value ?? _role),
                      ),
                    ),
                    AppButton(
                      label: 'Buat Undangan',
                      isLoading: _saving,
                      icon: Icons.send_rounded,
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _saving = true);
                        try {
                          final repository = ref.read(appRepositoryProvider);
                          final allowed = _role == MembershipRole.member
                              ? await repository.canAddMember(communityId)
                              : await repository.canAddAdmin(communityId);
                          if (!allowed) {
                            throw const TenantException(
                              'Batas plan komunitas sudah tercapai.',
                            );
                          }
                          await repository.createInvitation(
                            communityId: communityId,
                            invitedBy: auth.profile!.id,
                            email: _email.text,
                            fullName: _name.text,
                            phoneNumber: _phone.text.isEmpty
                                ? null
                                : PhoneNumberFormatter
                                    .normalizeIndonesianPhoneNumber(
                                        _phone.text),
                            role: _role,
                          );
                          ref.invalidate(invitationsProvider(communityId));
                          _email.clear();
                          _name.clear();
                          _phone.clear();
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          invitations.when(
            loading: () => const SizedBox(height: 280, child: LoadingView()),
            error: (error, _) => ErrorView(message: '$error'),
            data: (items) => items.isEmpty
                ? const Card(
                    child: SizedBox(
                      height: 220,
                      child: EmptyState(
                        title: 'Belum ada undangan',
                        message: 'Undangan yang dibuat akan tampil di sini.',
                        icon: Icons.mail_outline_rounded,
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
                        final item = items[index];
                        final link = Uri.base
                            .resolve(
                              '/#/accept-invitation?token=${item.token}',
                            )
                            .toString();
                        return ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(item.invitedEmail),
                          subtitle: Text(
                            '${item.role.label} · ${item.status} · berlaku sampai ${AppFormatters.date(item.expiresAt)}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Salin link undangan',
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: link),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Link undangan disalin.'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded),
                              ),
                              IconButton(
                                tooltip: 'Kirim ulang undangan',
                                onPressed: item.status == 'accepted'
                                    ? null
                                    : () async {
                                        await ref
                                            .read(appRepositoryProvider)
                                            .resendInvitation(item.id);
                                        ref.invalidate(
                                          invitationsProvider(communityId),
                                        );
                                      },
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                              IconButton(
                                tooltip: 'Batalkan undangan',
                                onPressed: item.status != 'pending'
                                    ? null
                                    : () async {
                                        await ref
                                            .read(appRepositoryProvider)
                                            .cancelInvitation(item.id);
                                        ref.invalidate(
                                          invitationsProvider(communityId),
                                        );
                                      },
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class AcceptInvitationPage extends ConsumerStatefulWidget {
  const AcceptInvitationPage({super.key, this.initialToken});
  final String? initialToken;

  @override
  ConsumerState<AcceptInvitationPage> createState() =>
      _AcceptInvitationPageState();
}

class _AcceptInvitationPageState extends ConsumerState<AcceptInvitationPage> {
  late final TextEditingController _token;
  CommunityInvitation? _invitation;
  String? _message;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken);
    if (widget.initialToken?.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    setState(() => _loading = true);
    final invitation = await ref
        .read(appRepositoryProvider)
        .getInvitationByToken(_token.text.trim());
    if (mounted) {
      setState(() {
        _invitation = invitation;
        _message = invitation == null ? 'Undangan tidak valid.' : null;
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      context.go(
        '/login?next=/accept-invitation&token=${Uri.encodeComponent(_token.text)}',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(appRepositoryProvider).acceptInvitation(
            token: _token.text,
            userId: auth.profile!.id,
            userEmail: auth.profile!.email,
          );
      await ref.read(authControllerProvider.notifier).refreshTenancy();
      if (!mounted) return;
      final membership = ref
          .read(authControllerProvider)
          .memberships
          .firstWhere((item) => item.communityId == _invitation!.communityId);
      ref
          .read(authControllerProvider.notifier)
          .selectCommunity(membership.communityId);
      context.go(membershipHomePath(membership.role));
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terima Undangan',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'Token Undangan',
                        controller: _token,
                      ),
                      const SizedBox(height: 14),
                      if (_invitation == null)
                        AppButton(
                          label: 'Validasi Undangan',
                          onPressed: _validate,
                          isLoading: _loading,
                          expand: true,
                          icon: Icons.verified_user_rounded,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _invitation!.communityName ?? 'Komunitas',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text('Role: ${_invitation!.role.label}'),
                              Text(
                                'Berlaku sampai ${AppFormatters.date(_invitation!.expiresAt)}',
                              ),
                              const SizedBox(height: 16),
                              if (_invitation!.status == 'pending' &&
                                  !_invitation!.isExpired)
                                AppButton(
                                  label: 'Terima Undangan',
                                  onPressed: _accept,
                                  isLoading: _loading,
                                  expand: true,
                                  icon: Icons.check_circle_rounded,
                                )
                              else
                                Text(
                                  _invitation!.isExpired
                                      ? 'Undangan sudah kedaluwarsa.'
                                      : 'Status undangan: ${_invitation!.status}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _message!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class JoinRequestsPage extends ConsumerWidget {
  const JoinRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityId = ref.watch(authControllerProvider).selectedCommunityId!;
    final requests = ref.watch(joinRequestsProvider(communityId));
    return PageScaffold(
      title: 'Permintaan Bergabung',
      subtitle: 'Tinjau warga yang mendaftar melalui kode komunitas.',
      child: requests.when(
        loading: () => const SizedBox(height: 300, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) {
          final pending =
              items.where((item) => item.status == 'pending').toList();
          if (pending.isEmpty) {
            return const Card(
              child: SizedBox(
                height: 240,
                child: EmptyState(
                  title: 'Tidak ada permintaan baru',
                  message: 'Permintaan via kode akan muncul di sini.',
                  icon: Icons.how_to_reg_rounded,
                ),
              ),
            );
          }
          return Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = pending[index];
                return ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  title: Text(item.requesterName ?? 'Pengguna KasWarga'),
                  subtitle: Text(
                    '${item.requesterEmail ?? '-'}\n${item.requestNote ?? 'Tanpa catatan'}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Setujui',
                        onPressed: () async {
                          await ref
                              .read(appRepositoryProvider)
                              .reviewJoinRequest(
                                requestId: item.id,
                                approved: true,
                              );
                          ref.invalidate(joinRequestsProvider(communityId));
                          ref.invalidate(membersProvider(communityId));
                        },
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tolak',
                        onPressed: () =>
                            _showRejectDialog(context, ref, item, communityId),
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    WidgetRef ref,
    CommunityJoinRequest request,
    String communityId,
  ) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak Permintaan'),
        content: AppTextField(
          label: 'Alasan Penolakan',
          controller: reason,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirmed == true && reason.text.trim().isNotEmpty) {
      await ref.read(appRepositoryProvider).reviewJoinRequest(
            requestId: request.id,
            approved: false,
            rejectionReason: reason.text,
          );
      ref.invalidate(joinRequestsProvider(communityId));
    }
    reason.dispose();
  }
}

class CommunitySettingsPage extends ConsumerStatefulWidget {
  const CommunitySettingsPage({super.key});

  @override
  ConsumerState<CommunitySettingsPage> createState() =>
      _CommunitySettingsPageState();
}

class _CommunitySettingsPageState extends ConsumerState<CommunitySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();
  final _code = TextEditingController();
  bool _joinEnabled = true;
  bool _approvalRequired = true;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _city,
      _province,
      _postalCode,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final membership = auth.selectedMembership!;
    final community = membership.community;
    final subscription = ref.watch(communitySubscriptionProvider(community.id));
    if (!_initialized) {
      _initialized = true;
      _name.text = community.name;
      _address.text = community.address;
      _city.text = community.city;
      _province.text = community.province;
      _postalCode.text = community.postalCode;
      _code.text = community.communityCode;
      _joinEnabled = community.isCodeJoinEnabled;
      _approvalRequired = community.requireAdminApproval;
    }
    return PageScaffold(
      title: 'Pengaturan Komunitas',
      subtitle:
          'Kelola identitas, kode bergabung, dan aturan penerimaan warga.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profil Komunitas',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subscription.when(
                          loading: () => const Chip(label: Text('...')),
                          error: (_, __) =>
                              const Chip(label: Text('Plan tidak tersedia')),
                          data: (item) => Chip(
                            avatar: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 18,
                            ),
                            label: Text('Plan ${item?.plan.name ?? 'Free'}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Nama Komunitas',
                      controller: _name,
                      validator: (value) => Validators.required(
                        value,
                        field: 'Nama komunitas',
                      ),
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
                            label: 'Kota',
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Kode Pos',
                            controller: _postalCode,
                            validator: (value) =>
                                Validators.required(value, field: 'Kode pos'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Kode Komunitas',
                      controller: _code,
                      validator: CommunityCode.validationMessage,
                      suffixIcon: IconButton(
                        tooltip: 'Generate ulang',
                        onPressed: () => setState(
                          () => _code.text = CommunityCode.generate(_name.text),
                        ),
                        icon: const Icon(Icons.autorenew_rounded),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Izinkan bergabung melalui kode'),
                      value: _joinEnabled,
                      onChanged: (value) =>
                          setState(() => _joinEnabled = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Wajib persetujuan admin'),
                      value: _approvalRequired,
                      onChanged: (value) =>
                          setState(() => _approvalRequired = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Simpan Pengaturan',
                isLoading: _saving,
                icon: Icons.save_rounded,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _saving = true);
                  try {
                    await ref
                        .read(appRepositoryProvider)
                        .updateCommunitySettings(
                          communityId: community.id,
                          name: _name.text,
                          address: _address.text,
                          city: _city.text,
                          province: _province.text,
                          postalCode: _postalCode.text,
                          communityCode: _code.text,
                          isCodeJoinEnabled: _joinEnabled,
                          requireAdminApproval: _approvalRequired,
                        );
                    await ref
                        .read(authControllerProvider.notifier)
                        .refreshTenancy(
                          preferredCommunityId: community.id,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Pengaturan komunitas disimpan.'),
                        ),
                      );
                    }
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const PageScaffold(
        title: 'Subscription SaaS',
        subtitle: 'Pantau plan komunitas. Billing belum diaktifkan pada MVP.',
        child: Card(
          child: SizedBox(
            height: 280,
            child: EmptyState(
              title: 'Billing sedang disiapkan',
              message:
                  'Struktur plan Free dan Pro sudah tersedia. Payment gateway akan ditambahkan pada fase berikutnya.',
              icon: Icons.workspace_premium_rounded,
            ),
          ),
        ),
      );
}
