import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/services/file_upload_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../payment_accounts/presentation/payment_accounts_page.dart';

class AdminBillsPage extends ConsumerStatefulWidget {
  const AdminBillsPage({super.key, this.verificationOnly = false});
  final bool verificationOnly;

  @override
  ConsumerState<AdminBillsPage> createState() => _AdminBillsPageState();
}

class _AdminBillsPageState extends ConsumerState<AdminBillsPage> {
  BillStatus? _status;

  @override
  void initState() {
    super.initState();
    if (widget.verificationOnly) {
      _status = BillStatus.waitingVerification;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = profile.communityId ?? AppConstants.demoCommunityId;
    final bills = ref.watch(
      billsProvider(
        (communityId: communityId, memberId: null, status: _status),
      ),
    );
    final accounts = ref.watch(
      paymentAccountsProvider(
        (communityId: communityId, activeOnly: false),
      ),
    );
    return PageScaffold(
      title: widget.verificationOnly ? 'Verifikasi Pembayaran' : 'Tagihan Warga',
      subtitle: widget.verificationOnly
          ? 'Periksa rekening tujuan dan bukti transfer sebelum menyetujui.'
          : 'Pantau status seluruh tagihan anggota komunitas.',
      child: Column(
        children: [
          if (!widget.verificationOnly)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppDropdown<BillStatus?>(
                  label: 'Filter Status',
                  value: _status,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Semua Status'),
                    ),
                    for (final status in BillStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
            ),
          if (!widget.verificationOnly) const SizedBox(height: 16),
          bills.when(
            loading: () => const SizedBox(height: 360, child: LoadingView()),
            error: (error, _) => ErrorView(message: '$error'),
            data: (items) {
              if (items.isEmpty) {
                return Card(
                  child: SizedBox(
                    height: 300,
                    child: EmptyState(
                      title: widget.verificationOnly
                          ? 'Tidak ada antrean verifikasi'
                          : 'Belum ada tagihan',
                      message: widget.verificationOnly
                          ? 'Pembayaran baru akan tampil setelah warga mengunggah bukti transfer.'
                          : 'Buat iuran untuk menghasilkan tagihan warga.',
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                );
              }
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final bill = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFDDE9E2),
                        child: Text(
                          (bill.memberName ?? 'W')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        bill.memberName ?? 'Warga',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${bill.title ?? 'Iuran'} • ${AppFormatters.rupiah(bill.amount)}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: bill.status),
                          if (bill.status == BillStatus.waitingVerification)
                            FilledButton.tonal(
                              onPressed: () => _showVerification(
                                bill,
                                accounts.valueOrNull
                                    ?.where(
                                      (account) =>
                                          account.id ==
                                          bill.selectedPaymentAccountId,
                                    )
                                    .firstOrNull,
                              ),
                              child: const Text('Periksa'),
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

  Future<void> _showVerification(
    Bill bill,
    PaymentAccount? paymentAccount,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _VerificationDialog(
        bill: bill,
        paymentAccount: paymentAccount,
      ),
    );
    if (result == true) ref.invalidate(billsProvider);
  }
}

class _VerificationDialog extends ConsumerStatefulWidget {
  const _VerificationDialog({
    required this.bill,
    required this.paymentAccount,
  });
  final Bill bill;
  final PaymentAccount? paymentAccount;

  @override
  ConsumerState<_VerificationDialog> createState() =>
      _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<_VerificationDialog> {
  final _note = TextEditingController();
  late final Future<String?> _proofUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _proofUrl = ref.read(appRepositoryProvider).getSignedStorageUrl(
          bucket: AppConstants.paymentProofBucket,
          path: widget.bill.paymentProofUrl,
        );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _verify(bool approved) async {
    if (!approved && _note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alasan penolakan wajib diisi.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(appRepositoryProvider).verifyBill(
            billId: widget.bill.id,
            approved: approved,
            note: _note.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verifikasi gagal: $error')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Verifikasi Pembayaran'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Warga', widget.bill.memberName ?? '-'),
              _DetailRow('Iuran', widget.bill.title ?? '-'),
              _DetailRow('Nominal', AppFormatters.rupiah(widget.bill.amount)),
              _DetailRow(
                'Tanggal Transfer',
                AppFormatters.date(widget.bill.paymentDate),
              ),
              _DetailRow(
                'Rekening Tujuan',
                widget.paymentAccount == null
                    ? '-'
                    : '${widget.paymentAccount!.bankName} • ${widget.paymentAccount!.accountNumber}',
              ),
              _DetailRow(
                'Bukti Transfer',
                widget.bill.paymentProofUrl == null
                    ? 'Tidak tersedia'
                    : 'Sudah diunggah',
              ),
              if (widget.bill.paymentProofUrl != null) ...[
                const SizedBox(height: 14),
                FutureBuilder<String?>(
                  future: _proofUrl,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 160,
                        child: LoadingView(message: 'Memuat bukti transfer...'),
                      );
                    }
                    if (snapshot.data == null) {
                      return Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Preview bukti tersedia saat terhubung ke Supabase.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        snapshot.data!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 120,
                          child: ErrorView(
                            message: 'Gambar bukti tidak dapat ditampilkan.',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: 'Catatan / Alasan Penolakan',
                controller: _note,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              const Text(
                'Catatan wajib diisi jika pembayaran ditolak.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            onPressed: _saving ? null : () => _verify(false),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Tolak'),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _verify(true),
            child: Text(_saving ? 'Memproses...' : 'Setujui'),
          ),
        ],
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class MemberBillsPage extends ConsumerWidget {
  const MemberBillsPage({super.key, this.historyOnly = false});
  final bool historyOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = profile.communityId ?? AppConstants.demoCommunityId;
    return FutureBuilder<String?>(
      future: ref.read(appRepositoryProvider).getMemberIdForUser(profile.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PageScaffold(
            title: historyOnly ? 'Riwayat Pembayaran' : 'Tagihan Saya',
            subtitle: 'Menyiapkan data warga...',
            child: const SizedBox(height: 360, child: LoadingView()),
          );
        }
        if (snapshot.data == null && AppConfig.isSupabaseConfigured) {
          return PageScaffold(
            title: historyOnly ? 'Riwayat Pembayaran' : 'Tagihan Saya',
            subtitle: 'Akun belum terhubung ke data anggota.',
            child: const Card(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  title: 'Data anggota belum ditautkan',
                  message:
                      'Hubungi admin komunitas untuk menghubungkan akun login Anda.',
                  icon: Icons.link_off_rounded,
                ),
              ),
            ),
          );
        }
        final memberId = snapshot.data ?? AppConstants.demoMemberId;
        final bills = ref.watch(
          billsProvider(
            (communityId: communityId, memberId: memberId, status: null),
          ),
        );
        return PageScaffold(
          title: historyOnly ? 'Riwayat Pembayaran' : 'Tagihan Saya',
          subtitle: historyOnly
              ? 'Lihat pembayaran dan hasil verifikasi sebelumnya.'
              : 'Pilih tagihan untuk melihat rekening dan mengunggah bukti.',
          child: bills.when(
            loading: () => const SizedBox(height: 360, child: LoadingView()),
            error: (error, _) => ErrorView(message: '$error'),
            data: (items) {
              final filtered = historyOnly
                  ? items.where((item) => item.status != BillStatus.unpaid).toList()
                  : items;
              if (filtered.isEmpty) {
                return Card(
                  child: SizedBox(
                    height: 300,
                    child: EmptyState(
                      title: historyOnly
                          ? 'Belum ada riwayat pembayaran'
                          : 'Tidak ada tagihan',
                      message: historyOnly
                          ? 'Pembayaran yang Anda kirim akan tampil di sini.'
                          : 'Tagihan baru dari pengurus akan tampil di sini.',
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final bill in filtered) ...[
                    Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.go('/member/bills/${bill.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.forest.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppColors.forest,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill.title ?? 'Iuran Warga',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      AppFormatters.rupiah(bill.amount),
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    if (bill.adminNote != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Catatan: ${bill.adminNote}',
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              StatusBadge(status: bill.status),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class MemberBillDetailPage extends ConsumerStatefulWidget {
  const MemberBillDetailPage({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<MemberBillDetailPage> createState() =>
      _MemberBillDetailPageState();
}

class _MemberBillDetailPageState extends ConsumerState<MemberBillDetailPage> {
  String? _accountId;
  DateTime? _paymentDate;
  PickedImage? _image;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = profile.communityId ?? AppConstants.demoCommunityId;
    return FutureBuilder<String?>(
      future: ref.read(appRepositoryProvider).getMemberIdForUser(profile.id),
      builder: (context, memberSnapshot) {
        if (memberSnapshot.connectionState == ConnectionState.waiting) {
          return const PageScaffold(
            title: 'Detail Tagihan',
            subtitle: 'Menyiapkan data warga...',
            child: SizedBox(height: 360, child: LoadingView()),
          );
        }
        if (memberSnapshot.data == null && AppConfig.isSupabaseConfigured) {
          return const PageScaffold(
            title: 'Detail Tagihan',
            subtitle: 'Akun belum terhubung ke data anggota.',
            child: Card(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  title: 'Data anggota belum ditautkan',
                  message:
                      'Hubungi admin komunitas untuk menghubungkan akun login Anda.',
                  icon: Icons.link_off_rounded,
                ),
              ),
            ),
          );
        }
        final memberId = memberSnapshot.data ?? AppConstants.demoMemberId;
        final bills = ref.watch(
          billsProvider(
            (communityId: communityId, memberId: memberId, status: null),
          ),
        );
        final accounts = ref.watch(
          paymentAccountsProvider(
            (communityId: communityId, activeOnly: true),
          ),
        );
        return PageScaffold(
          title: 'Detail Tagihan',
          subtitle: 'Transfer manual lalu unggah bukti pembayaran.',
          child: bills.when(
            loading: () => const SizedBox(height: 380, child: LoadingView()),
            error: (error, _) => ErrorView(message: '$error'),
            data: (items) {
              final bill = items.where((item) => item.id == widget.billId).firstOrNull;
              if (bill == null) {
                return const ErrorView(
                  message: 'Tagihan tidak ditemukan atau tidak dapat diakses.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bill.title ?? 'Iuran Warga',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              StatusBadge(status: bill.status),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Nominal Tagihan',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.rupiah(bill.amount),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (bill.adminNote != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Catatan pengurus: ${bill.adminNote}',
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Pilih rekening tujuan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  accounts.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => ErrorView(message: '$error'),
                    data: (items) => Column(
                      children: [
                        for (final account in items) ...[
                          RadioListTile<String>(
                            value: account.id,
                            groupValue: _accountId,
                            onChanged: bill.status == BillStatus.paid
                                ? null
                                : (value) => setState(() => _accountId = value),
                            title: PaymentAccountCard(account: account),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  if (bill.status != BillStatus.paid) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Unggah Bukti Transfer',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            AppDatePicker(
                              label: 'Tanggal Transfer',
                              value: _paymentDate,
                              onChanged: (value) =>
                                  setState(() => _paymentDate = value),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final image =
                                      await FileUploadService.pickImage();
                                  if (image != null) {
                                    setState(() => _image = image);
                                  }
                                } on FormatException catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                _image == null
                                    ? 'Pilih Gambar Bukti'
                                    : _image!.name,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Format JPG, PNG, atau WebP. Maksimal 5 MB.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 18),
                            AppButton(
                              label: 'Kirim untuk Verifikasi',
                              icon: Icons.cloud_upload_rounded,
                              isLoading: _submitting,
                              expand: true,
                              onPressed: () => _submit(
                                bill: bill,
                                profile: profile,
                                communityId: communityId,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _submit({
    required Bill bill,
    required UserProfile profile,
    required String communityId,
  }) async {
    if (_accountId == null || _paymentDate == null || _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih rekening, tanggal transfer, dan gambar bukti pembayaran.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(appRepositoryProvider).submitPayment(
            billId: bill.id,
            paymentAccountId: _accountId!,
            paymentDate: _paymentDate!,
            proofBytes: _image!.bytes,
            fileExtension: _image!.extension,
            communityId: communityId,
            userId: profile.id,
          );
      ref.invalidate(billsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti pembayaran dikirim untuk verifikasi.'),
          ),
        );
        context.go('/member/bills');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bukti pembayaran gagal dikirim: $error')),
        );
        setState(() => _submitting = false);
      }
    }
  }
}
