import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../services/app_repository.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) => AppRepository());

final communitiesProvider = FutureProvider<List<Community>>((ref) {
  return ref.watch(appRepositoryProvider).getCommunities();
});

final profilesProvider = FutureProvider<List<UserProfile>>((ref) {
  return ref.watch(appRepositoryProvider).getProfiles();
});

final paymentAccountsProvider = FutureProvider.family<
    List<PaymentAccount>,
    ({String communityId, bool activeOnly})>((ref, arg) {
  return ref.watch(appRepositoryProvider).getPaymentAccounts(
        communityId: arg.communityId,
        activeOnly: arg.activeOnly,
      );
});

final membersProvider =
    FutureProvider.family<List<CommunityMember>, String>((ref, communityId) {
  return ref.watch(appRepositoryProvider).getMembers(communityId);
});

final duesProvider =
    FutureProvider.family<List<Due>, String>((ref, communityId) {
  return ref.watch(appRepositoryProvider).getDues(communityId);
});

final billsProvider = FutureProvider.family<
    List<Bill>,
    ({String communityId, String? memberId, BillStatus? status})>((ref, arg) {
  return ref.watch(appRepositoryProvider).getBills(
        communityId: arg.communityId,
        memberId: arg.memberId,
        status: arg.status,
      );
});

final expensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, communityId) {
  return ref.watch(appRepositoryProvider).getExpenses(communityId);
});

final announcementsProvider =
    FutureProvider.family<List<Announcement>, String>((ref, communityId) {
  return ref.watch(appRepositoryProvider).getAnnouncements(communityId);
});

final cashSummaryProvider =
    FutureProvider.family<CashSummary, String>((ref, communityId) {
  return ref.watch(appRepositoryProvider).getCashSummary(communityId);
});
