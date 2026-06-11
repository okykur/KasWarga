import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/csv_exporter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  BillStatus? _status;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String? _memberId;
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final communityId = ref.watch(authControllerProvider).selectedCommunityId!;
    final bills = ref.watch(
      billsProvider(
        (communityId: communityId, memberId: null, status: _status),
      ),
    );
    final expenses = ref.watch(expensesProvider(communityId));
    final members = ref.watch(membersProvider(communityId));
    final accounts = ref.watch(
      paymentAccountsProvider(
        (communityId: communityId, activeOnly: false),
      ),
    );
    final filteredBills = _filterBills(bills.valueOrNull ?? const []);
    final filteredExpenses = (expenses.valueOrNull ?? const [])
        .where(
          (item) =>
              item.expenseDate.month == _month &&
              item.expenseDate.year == _year,
        )
        .toList();
    return PageScaffold(
      title: 'Laporan',
      subtitle: 'Filter transaksi lalu unduh CSV yang ramah Excel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
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
                  SizedBox(
                    width: 150,
                    child: AppDropdown<int>(
                      label: 'Tahun',
                      value: _year,
                      items: [
                        for (var year = DateTime.now().year - 3;
                            year <= DateTime.now().year + 1;
                            year++)
                          DropdownMenuItem(
                            value: year,
                            child: Text('$year'),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _year = value ?? _year),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: AppDropdown<BillStatus?>(
                      label: 'Status Pembayaran',
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
                  SizedBox(
                    width: 220,
                    child: AppDropdown<String>(
                      label: 'Anggota',
                      value: _memberId ?? '',
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua Anggota'),
                        ),
                        for (final member in members.valueOrNull ?? const [])
                          DropdownMenuItem(
                            value: member.id,
                            child: Text(member.fullName),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _memberId = value == '' ? null : value,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: AppDropdown<String>(
                      label: 'Rekening Tujuan',
                      value: _accountId ?? '',
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua Rekening'),
                        ),
                        for (final account in accounts.valueOrNull ?? const [])
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              '${account.bankName} • ${account.accountNumber}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _accountId = value == '' ? null : value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth >= 760 ? 360.0 : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _ReportCard(
                      title: 'Laporan Pembayaran',
                      description:
                          'Status, warga, nominal, tanggal, dan rekening tujuan.',
                      icon: Icons.receipt_long_rounded,
                      onExport: bills.valueOrNull == null
                          ? null
                          : () => _exportBills(filteredBills),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ReportCard(
                      title: 'Laporan Pengeluaran',
                      description:
                          'Penggunaan kas dan referensi bukti nota komunitas.',
                      icon: Icons.payments_rounded,
                      onExport: expenses.valueOrNull == null
                          ? null
                          : () => _exportExpenses(filteredExpenses),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ReportCard(
                      title: 'Transfer per Rekening',
                      description:
                          'Rekap pembayaran berdasarkan rekening yang dipilih.',
                      icon: Icons.account_balance_rounded,
                      onExport: bills.valueOrNull == null
                          ? null
                          : () => _exportAccounts(filteredBills),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Export PDF disiapkan sebagai fase berikutnya. CSV saat ini menggunakan delimiter titik koma agar nyaman dibuka di Excel regional Indonesia.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  List<Bill> _filterBills(List<Bill> items) {
    return items.where((bill) {
      return bill.dueMonth == _month &&
          bill.dueYear == _year &&
          (_memberId == null || bill.memberId == _memberId) &&
          (_accountId == null || bill.selectedPaymentAccountId == _accountId);
    }).toList();
  }

  void _exportBills(List<Bill> items) {
    CsvExporter.download(
      filename: 'kaswarga-pembayaran-$_month-$_year.csv',
      headers: const [
        'Warga',
        'Iuran',
        'Nominal',
        'Status',
        'Tanggal Pembayaran',
        'Rekening Tujuan',
      ],
      rows: [
        for (final bill in items)
          [
            bill.memberName ?? '',
            bill.title ?? '',
            bill.amount,
            bill.status.label,
            AppFormatters.shortDate(bill.paymentDate),
            bill.selectedPaymentAccountId ?? '',
          ],
      ],
    );
  }

  void _exportExpenses(List<Expense> items) {
    CsvExporter.download(
      filename: 'kaswarga-pengeluaran-$_month-$_year.csv',
      headers: const ['Tanggal', 'Judul', 'Deskripsi', 'Nominal', 'Bukti'],
      rows: [
        for (final expense in items)
          [
            AppFormatters.shortDate(expense.expenseDate),
            expense.title,
            expense.description ?? '',
            expense.amount,
            expense.receiptImageUrl ?? '',
          ],
      ],
    );
  }

  void _exportAccounts(List<Bill> items) {
    CsvExporter.download(
      filename: 'kaswarga-transfer-rekening-$_month-$_year.csv',
      headers: const ['Rekening Tujuan', 'Jumlah Transaksi', 'Total Nominal'],
      rows: [
        for (final entry in _groupByAccount(items).entries)
          [
            entry.key,
            entry.value.length,
            entry.value.fold<double>(
              0,
              (sum, bill) => sum + bill.amount,
            ),
          ],
      ],
    );
  }

  Map<String, List<Bill>> _groupByAccount(List<Bill> items) {
    final result = <String, List<Bill>>{};
    for (final bill in items.where((item) => item.status == BillStatus.paid)) {
      result
          .putIfAbsent(
            bill.selectedPaymentAccountId ?? 'Tidak diketahui',
            () => [],
          )
          .add(bill);
    }
    return result;
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onExport,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.forest, size: 30),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export CSV'),
              ),
            ],
          ),
        ),
      );
}
