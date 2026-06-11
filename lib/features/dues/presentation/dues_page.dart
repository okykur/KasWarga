import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class DuesPage extends ConsumerWidget {
  const DuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityId = ref.watch(authControllerProvider).selectedCommunityId!;
    final dues = ref.watch(duesProvider(communityId));
    return PageScaffold(
      title: 'Iuran Bulanan',
      subtitle: 'Buat iuran dan generate tagihan untuk semua anggota aktif.',
      action: AppButton(
        label: 'Buat Iuran',
        icon: Icons.add_card_rounded,
        onPressed: () async {
          final saved = await showDialog<bool>(
            context: context,
            builder: (_) => _DueForm(communityId: communityId),
          );
          if (saved == true) {
            ref.invalidate(duesProvider);
            ref.invalidate(billsProvider);
          }
        },
      ),
      child: dues.when(
        loading: () => const SizedBox(height: 380, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return const Card(
              child: SizedBox(
                height: 320,
                child: EmptyState(
                  title: 'Belum ada iuran',
                  message:
                      'Buat iuran pertama untuk menghasilkan tagihan warga aktif.',
                  icon: Icons.receipt_long_outlined,
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
                final due = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${due.month}',
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    due.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${due.month}/${due.year} • Jatuh tempo ${AppFormatters.date(due.dueDate)}',
                  ),
                  trailing: Text(
                    AppFormatters.rupiah(due.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

class _DueForm extends ConsumerStatefulWidget {
  const _DueForm({required this.communityId});
  final String communityId;

  @override
  ConsumerState<_DueForm> createState() => _DueFormState();
}

class _DueFormState extends ConsumerState<_DueForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController(text: 'Iuran Bulanan');
  final _description = TextEditingController();
  final _amount = TextEditingController(text: '150000');
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  DateTime _dueDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    10,
  );
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
        title: const Text('Buat Iuran'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Judul Iuran',
                    controller: _title,
                    validator: (value) =>
                        Validators.required(value, field: 'Judul iuran'),
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
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<int>(
                          label: 'Bulan',
                          value: _month,
                          items: [
                            for (var month = 1; month <= 12; month++)
                              DropdownMenuItem(
                                value: month,
                                child: Text('$month'),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _month = value ?? _month),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Tahun',
                          controller: TextEditingController(text: '$_year'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) =>
                              _year = int.tryParse(value) ?? _year,
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null ||
                                parsed < 2020 ||
                                parsed > 2100) {
                              return 'Tahun tidak valid.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppDatePicker(
                    label: 'Tanggal Jatuh Tempo',
                    value: _dueDate,
                    onChanged: (value) => setState(() => _dueDate = value),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF8B5C00),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tagihan otomatis dibuat untuk seluruh anggota berstatus aktif.',
                          ),
                        ),
                      ],
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
                      await ref.read(appRepositoryProvider).createDue(
                            communityId: widget.communityId,
                            title: _title.text,
                            description: _description.text,
                            month: _month,
                            year: _year,
                            amount:
                                double.parse(_amount.text.replaceAll('.', '')),
                            dueDate: _dueDate,
                          );
                      if (!mounted) return;
                      Navigator.pop(this.context, true);
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Iuran gagal dibuat. Pastikan periode belum pernah digunakan. $error',
                            ),
                          ),
                        );
                        setState(() => _saving = false);
                      }
                    }
                  },
            child: Text(_saving ? 'Membuat...' : 'Buat dan Generate'),
          ),
        ],
      );
}
