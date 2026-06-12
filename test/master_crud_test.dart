import 'package:flutter_test/flutter_test.dart';
import 'package:kaswarga/core/constants/app_constants.dart';
import 'package:kaswarga/shared/services/app_repository.dart';

void main() {
  final repository = AppRepository();

  test('master iuran dapat diedit dan tagihan terbuka ikut diperbarui',
      () async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final title = 'Iuran Tes $suffix';

    await repository.createDue(
      communityId: AppConstants.demoCommunityId,
      title: title,
      month: 12,
      year: 2099,
      amount: 100000,
      dueDate: DateTime(2099, 12, 10),
    );

    final created = (await repository.getDues(AppConstants.demoCommunityId))
        .singleWhere((item) => item.title == title);
    final store = DemoDataStore.instance;
    final rawBills =
        store.bills.where((item) => item['dues_id'] == created.id).toList();
    while (rawBills.length < 3) {
      final id =
          store.upsert(store.bills, 'test-bill-$suffix-${rawBills.length}', {
        'dues_id': created.id,
        'community_id': created.communityId,
        'member_id': 'test-member-${rawBills.length}',
        'amount': 100000,
        'status': 'unpaid',
        'dues': {
          'title': title,
          'month': created.month,
          'year': created.year,
        },
      });
      rawBills.add(store.bills.singleWhere((item) => item['id'] == id));
    }
    rawBills[1]['status'] = 'waiting_verification';
    rawBills[2]['status'] = 'paid';

    await repository.saveDue(
      id: created.id,
      communityId: created.communityId,
      title: '$title Diperbarui',
      description: 'Nominal hasil edit.',
      month: created.month,
      year: created.year,
      amount: 125000,
      dueDate: DateTime(2099, 12, 15),
    );

    final updated = (await repository.getDues(AppConstants.demoCommunityId))
        .singleWhere((item) => item.id == created.id);
    final bills = await repository.getBills(
      communityId: AppConstants.demoCommunityId,
    );
    final generatedBills =
        bills.where((item) => item.duesId == created.id).toList();

    expect(updated.title, '$title Diperbarui');
    expect(updated.amount, 125000);
    expect(updated.dueDate.day, 15);
    expect(generatedBills, isNotEmpty);
    expect(rawBills[0]['amount'], 125000);
    expect(rawBills[1]['status'], BillStatus.waitingVerification.value);
    expect(rawBills[1]['amount'], 100000);
    expect(rawBills[2]['status'], BillStatus.paid.value);
    expect(rawBills[2]['amount'], 100000);
  });

  test('master pengeluaran dapat ditambah lalu diedit', () async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final title = 'Pengeluaran Tes $suffix';

    await repository.saveExpense(
      communityId: AppConstants.demoCommunityId,
      title: title,
      amount: 50000,
      expenseDate: DateTime(2099, 1, 1),
      userId: '33333333-3333-3333-3333-333333333333',
    );

    final created = (await repository.getExpenses(AppConstants.demoCommunityId))
        .singleWhere((item) => item.title == title);
    await repository.saveExpense(
      id: created.id,
      communityId: created.communityId,
      title: '$title Diperbarui',
      description: 'Keterangan hasil edit.',
      amount: 75000,
      expenseDate: DateTime(2099, 1, 2),
      userId: '33333333-3333-3333-3333-333333333333',
      existingReceiptPath: created.receiptImageUrl,
    );

    final updated = (await repository.getExpenses(AppConstants.demoCommunityId))
        .singleWhere((item) => item.id == created.id);
    expect(updated.title, '$title Diperbarui');
    expect(updated.amount, 75000);
    expect(updated.expenseDate.day, 2);
  });
}
