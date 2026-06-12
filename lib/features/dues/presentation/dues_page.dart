import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
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
      subtitle: 'Buat, lihat, dan ubah master iuran komunitas.',
      action: AppButton(
        label: 'Buat Iuran',
        icon: Icons.add_card_rounded,
        onPressed: () => _showForm(context, ref, communityId),
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
                    '${due.month}/${due.year} - Jatuh tempo '
                    '${AppFormatters.date(due.dueDate)}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AppFormatters.rupiah(due.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      MasterActions(
                        onView: () => _showDetail(context, due),
                        onEdit: () => _showForm(
                          context,
                          ref,
                          communityId,
                          due: due,
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
    WidgetRef ref,
    String communityId, {
    Due? due,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DueForm(communityId: communityId, due: due),
    );
    if (saved == true) {
      ref.invalidate(duesProvider);
      ref.invalidate(billsProvider);
      ref.invalidate(cashSummaryProvider);
    }
  }

  Future<void> _showDetail(BuildContext context, Due due) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Detail Iuran'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DetailRow(label: 'Judul', value: due.title),
                DetailRow(
                  label: 'Periode',
                  value: '${due.month}/${due.year}',
                ),
                DetailRow(
                  label: 'Nominal',
                  value: AppFormatters.rupiah(due.amount),
                ),
                DetailRow(
                  label: 'Jatuh tempo',
                  value: AppFormatters.date(due.dueDate),
                ),
                DetailRow(
                  label: 'Deskripsi',
                  value: due.description?.trim().isNotEmpty == true
                      ? due.description!
                      : '-',
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

class _DueForm extends ConsumerStatefulWidget {
  const _DueForm({required this.communityId, this.due});

  final String communityId;
  final Due? due;

  @override
  ConsumerState<_DueForm> createState() => _DueFormState();
}

class _DueFormState extends ConsumerState<_DueForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _yearController;
  late int _month;
  late int _year;
  late DateTime _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final due = widget.due;
    final now = DateTime.now();
    _title = TextEditingController(text: due?.title ?? 'Iuran Bulanan');
    _description = TextEditingController(text: due?.description);
    _amount = TextEditingController(
      text: due == null ? '150000' : due.amount.toStringAsFixed(0),
    );
    _month = due?.month ?? now.month;
    _year = due?.year ?? now.year;
    _yearController = TextEditingController(text: '$_year');
    _dueDate = due?.dueDate ?? DateTime(now.year, now.month, 10);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.due == null ? 'Buat Iuran' : 'Edit Iuran'),
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
                          controller: _yearController,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF8B5C00),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.due == null
                                ? 'Tagihan otomatis dibuat untuk seluruh '
                                    'anggota berstatus aktif.'
                                : 'Perubahan nominal hanya diterapkan ke '
                                    'tagihan belum bayar atau ditolak.',
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
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Menyimpan...'
                  : widget.due == null
                      ? 'Buat dan Generate'
                      : 'Simpan Perubahan',
            ),
          ),
        ],
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(appRepositoryProvider).saveDue(
            id: widget.due?.id,
            communityId: widget.communityId,
            title: _title.text,
            description: _description.text,
            month: _month,
            year: _year,
            amount: double.parse(_amount.text.replaceAll('.', '')),
            dueDate: _dueDate,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Iuran gagal disimpan. Pastikan judul dan periode tidak duplikat. '
            '$error',
          ),
        ),
      );
      setState(() => _saving = false);
    }
  }
}
