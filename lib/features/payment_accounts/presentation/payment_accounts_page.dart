import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class PaymentAccountsPage extends ConsumerWidget {
  const PaymentAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = profile.communityId ?? AppConstants.demoCommunityId;
    final accounts = ref.watch(
      paymentAccountsProvider(
        (communityId: communityId, activeOnly: false),
      ),
    );
    return PageScaffold(
      title: 'Rekening Tujuan',
      subtitle: 'Atur rekening yang digunakan warga untuk membayar iuran.',
      action: AppButton(
        label: 'Tambah Rekening',
        icon: Icons.add_rounded,
        onPressed: () => _showAccountForm(
          context,
          ref,
          profile: profile,
        ),
      ),
      child: accounts.when(
        loading: () => const SizedBox(height: 400, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return const Card(
              child: SizedBox(
                height: 320,
                child: EmptyState(
                  title: 'Belum ada rekening',
                  message:
                      'Tambahkan rekening tujuan agar warga dapat mengirim pembayaran.',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth =
                  constraints.maxWidth >= 780 ? 370.0 : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final account in items)
                    SizedBox(
                      width: itemWidth,
                      child: PaymentAccountCard(
                        account: account,
                        showAdminActions: true,
                        onEdit: () => _showAccountForm(
                          context,
                          ref,
                          profile: profile,
                          account: account,
                        ),
                        onDeactivate: account.isActive
                            ? () async {
                                final confirmed = await ConfirmationDialog.show(
                                  context,
                                  title: 'Nonaktifkan rekening?',
                                  message:
                                      'Rekening tidak akan ditampilkan kepada warga, tetapi histori pembayaran tetap tersimpan.',
                                  confirmLabel: 'Nonaktifkan',
                                  isDanger: true,
                                );
                                if (!confirmed) return;
                                await ref
                                    .read(appRepositoryProvider)
                                    .deactivatePaymentAccount(account.id);
                                ref.invalidate(paymentAccountsProvider);
                              }
                            : null,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAccountForm(
    BuildContext context,
    WidgetRef ref, {
    required UserProfile profile,
    PaymentAccount? account,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentAccountForm(
        profile: profile,
        account: account,
      ),
    );
    if (saved == true) ref.invalidate(paymentAccountsProvider);
  }
}

class PaymentAccountCard extends StatelessWidget {
  const PaymentAccountCard({
    super.key,
    required this.account,
    this.showAdminActions = false,
    this.onEdit,
    this.onDeactivate,
  });

  final PaymentAccount account;
  final bool showAdminActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bank ${account.bankName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (account.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Utama',
                      style: TextStyle(
                        color: Color(0xFF8B5C00),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'No. Rekening',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SelectableText(
              account.accountNumber,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text('Atas Nama: ${account.accountHolderName}'),
            if (account.branchName != null)
              Text(
                'Cabang: ${account.branchName}',
                style: const TextStyle(color: AppColors.muted),
              ),
            if (account.paymentInstruction != null) ...[
              const SizedBox(height: 14),
              Text(
                account.paymentInstruction!,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CopyableText(
                  value: account.accountNumber,
                  label: 'Salin Nomor Rekening',
                ),
                if (showAdminActions)
                  IconButton.outlined(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (showAdminActions && onDeactivate != null)
                  IconButton.outlined(
                    tooltip: 'Nonaktifkan',
                    onPressed: onDeactivate,
                    icon: const Icon(
                      Icons.block_rounded,
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
            if (!account.isActive) ...[
              const SizedBox(height: 12),
              const Text(
                'Rekening nonaktif',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentAccountForm extends ConsumerStatefulWidget {
  const _PaymentAccountForm({
    required this.profile,
    this.account,
  });

  final UserProfile profile;
  final PaymentAccount? account;

  @override
  ConsumerState<_PaymentAccountForm> createState() =>
      _PaymentAccountFormState();
}

class _PaymentAccountFormState
    extends ConsumerState<_PaymentAccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bank;
  late final TextEditingController _number;
  late final TextEditingController _holder;
  late final TextEditingController _branch;
  late final TextEditingController _instruction;
  late bool _isDefault;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _bank = TextEditingController(text: account?.bankName);
    _number = TextEditingController(text: account?.accountNumber);
    _holder = TextEditingController(text: account?.accountHolderName);
    _branch = TextEditingController(text: account?.branchName);
    _instruction = TextEditingController(text: account?.paymentInstruction);
    _isDefault = account?.isDefault ?? false;
    _isActive = account?.isActive ?? true;
  }

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _holder.dispose();
    _branch.dispose();
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.account == null ? 'Tambah Rekening' : 'Edit Rekening'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'Nama Bank',
                    controller: _bank,
                    validator: (value) =>
                        Validators.required(value, field: 'Nama bank'),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Nomor Rekening',
                    controller: _number,
                    keyboardType: TextInputType.number,
                    validator: Validators.accountNumber,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Nama Pemilik Rekening',
                    controller: _holder,
                    validator: (value) => Validators.required(
                      value,
                      field: 'Nama pemilik rekening',
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Cabang (opsional)',
                    controller: _branch,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Instruksi Pembayaran (opsional)',
                    controller: _instruction,
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jadikan rekening utama'),
                    subtitle: const Text(
                      'Rekening utama aktif lain otomatis tidak menjadi default.',
                    ),
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rekening aktif'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
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
                      await ref.read(appRepositoryProvider).savePaymentAccount(
                            id: widget.account?.id,
                            communityId: widget.profile.communityId ??
                                AppConstants.demoCommunityId,
                            bankName: _bank.text,
                            accountNumber: _number.text,
                            accountHolderName: _holder.text,
                            branchName: _branch.text,
                            instruction: _instruction.text,
                            isDefault: _isDefault && _isActive,
                            isActive: _isActive,
                            userId: widget.profile.id,
                          );
                      if (mounted) Navigator.pop(context, true);
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
