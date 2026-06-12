import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/services/file_upload_service.dart';
import '../../auth/presentation/auth_controller.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = ref.watch(authControllerProvider).selectedCommunityId!;
    final expenses = ref.watch(expensesProvider(communityId));
    return PageScaffold(
      title: 'Pengeluaran Kas',
      subtitle: 'Catat, lihat, dan ubah penggunaan dana komunitas.',
      action: AppButton(
        label: 'Catat Pengeluaran',
        icon: Icons.add_rounded,
        onPressed: () => _showForm(
          context,
          ref,
          communityId: communityId,
          userId: profile.id,
        ),
      ),
      child: expenses.when(
        loading: () => const SizedBox(height: 360, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return const Card(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  title: 'Belum ada pengeluaran',
                  message: 'Pengeluaran kas komunitas akan tercatat di sini.',
                  icon: Icons.payments_outlined,
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
                final expense = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF8DEDE),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.danger,
                    ),
                  ),
                  title: Text(
                    expense.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${AppFormatters.date(expense.expenseDate)}'
                    '${expense.receiptImageUrl == null ? '' : ' - Ada bukti nota'}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '-${AppFormatters.rupiah(expense.amount)}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      MasterActions(
                        onView: () => _showDetail(context, expense),
                        onEdit: () => _showForm(
                          context,
                          ref,
                          communityId: communityId,
                          userId: profile.id,
                          expense: expense,
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

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    required String communityId,
    required String userId,
    Expense? expense,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseForm(
        communityId: communityId,
        userId: userId,
        expense: expense,
      ),
    );
    if (saved == true) {
      ref.invalidate(expensesProvider);
      ref.invalidate(cashSummaryProvider);
    }
  }

  Future<void> _showDetail(BuildContext context, Expense expense) =>
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Detail Pengeluaran'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DetailRow(label: 'Judul', value: expense.title),
                DetailRow(
                  label: 'Tanggal',
                  value: AppFormatters.date(expense.expenseDate),
                ),
                DetailRow(
                  label: 'Nominal',
                  value: AppFormatters.rupiah(expense.amount),
                ),
                DetailRow(
                  label: 'Deskripsi',
                  value: expense.description?.trim().isNotEmpty == true
                      ? expense.description!
                      : '-',
                ),
                DetailRow(
                  label: 'Bukti nota',
                  value: expense.receiptImageUrl == null
                      ? 'Tidak ada'
                      : 'Tersedia',
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({
    required this.communityId,
    required this.userId,
    this.expense,
  });

  final String communityId;
  final String userId;
  final Expense? expense;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late DateTime _date;
  PickedImage? _receipt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _title = TextEditingController(text: expense?.title);
    _description = TextEditingController(text: expense?.description);
    _amount = TextEditingController(
      text: expense?.amount.toStringAsFixed(0),
    );
    _date = expense?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.expense == null ? 'Catat Pengeluaran' : 'Edit Pengeluaran',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Judul Pengeluaran',
                    controller: _title,
                    validator: (value) =>
                        Validators.required(value, field: 'Judul'),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Deskripsi (opsional)',
                    controller: _description,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Nominal',
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    validator: Validators.positiveAmount,
                  ),
                  const SizedBox(height: 14),
                  AppDatePicker(
                    label: 'Tanggal Pengeluaran',
                    value: _date,
                    onChanged: (value) => setState(() => _date = value),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(
                      _receipt != null
                          ? _receipt!.name
                          : widget.expense?.receiptImageUrl != null
                              ? 'Ganti Foto Nota'
                              : 'Pilih Foto Nota',
                    ),
                  ),
                  if (widget.expense?.receiptImageUrl != null &&
                      _receipt == null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Bukti nota lama tetap digunakan jika tidak diganti.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
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
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      );

  Future<void> _pickReceipt() async {
    try {
      final image = await FileUploadService.pickImage();
      if (image != null && mounted) setState(() => _receipt = image);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(appRepositoryProvider).saveExpense(
            id: widget.expense?.id,
            communityId: widget.communityId,
            title: _title.text,
            description: _description.text,
            amount: double.parse(_amount.text.replaceAll('.', '')),
            expenseDate: _date,
            userId: widget.userId,
            receiptBytes: _receipt?.bytes,
            receiptExtension: _receipt?.extension,
            existingReceiptPath: widget.expense?.receiptImageUrl,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
      setState(() => _saving = false);
    }
  }
}
