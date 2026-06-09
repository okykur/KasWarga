class AppConstants {
  const AppConstants._();

  static const appName = 'KasWarga';
  static const maxImageSizeBytes = 5 * 1024 * 1024;
  static const demoCommunityId = '11111111-1111-1111-1111-111111111111';
  static const demoMemberId = '44444444-4444-4444-4444-444444444441';
  static const paymentProofBucket = 'payment_proofs';
  static const expenseReceiptBucket = 'expense_receipts';
}

enum UserRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Admin Komunitas'),
  member('member', 'Warga');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.member,
    );
  }
}
enum BillStatus {
  unpaid('unpaid', 'Belum Bayar'),
  waitingVerification('waiting_verification', 'Menunggu Verifikasi'),
  paid('paid', 'Lunas'),
  rejected('rejected', 'Ditolak');

  const BillStatus(this.value, this.label);
  final String value;
  final String label;

  static BillStatus fromValue(String? value) {
    return BillStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BillStatus.unpaid,
    );
  }
}
