import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
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
      subtitle: 'Catat penggunaan dana dan lampirkan foto nota bila tersedia.',
      action: AppButton(
        label: 'Catat Pengeluaran',
        icon: Icons.add_rounded,
        onPressed: () async {
          final saved = await showDialog<bool>(
            context: context,
            builder: (_) => _ExpenseForm(
              communityId: communityId,
              userId: profile.id,
            ),
          );
          if (saved == true) {
            ref.invalidate(expensesProvider);
            ref.invalidate(cashSummaryProvider);
          }
        },
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
                    '${expense.receiptImageUrl == null ? '' : ' • Ada bukti nota'}',
                  ),
                  trailing: Text(
                    '-${AppFormatters.rupiah(expense.amount)}',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({required this.communityId, required this.userId});
  final String communityId;
  final String userId;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  PickedImage? _receipt;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Catat Pengeluaran'),
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
                    onPressed: () async {
                      try {
                        final image = await FileUploadService.pickImage();
                        if (image != null) setState(() => _receipt = image);
                      } on FormatException catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(
                      _receipt == null ? 'Pilih Foto Nota' : _receipt!.name,
                    ),
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
                      await ref.read(appRepositoryProvider).saveExpense(
                            communityId: widget.communityId,
                            title: _title.text,
                            description: _description.text,
                            amount:
                                double.parse(_amount.text.replaceAll('.', '')),
                            expenseDate: _date,
                            userId: widget.userId,
                            receiptBytes: _receipt?.bytes,
                            receiptExtension: _receipt?.extension,
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
