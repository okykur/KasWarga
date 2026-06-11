class AppConstants {
  const AppConstants._();

  static const appName = 'KasWarga';
  static const maxImageSizeBytes = 5 * 1024 * 1024;
  static const demoCommunityId = '11111111-1111-1111-1111-111111111111';
  static const demoSecondCommunityId = '11111111-1111-1111-1111-111111111112';
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

enum MembershipRole {
  owner('owner', 'Owner'),
  admin('admin', 'Admin'),
  treasurer('treasurer', 'Bendahara'),
  member('member', 'Warga');

  const MembershipRole(this.value, this.label);
  final String value;
  final String label;

  bool get canManage =>
      this == MembershipRole.owner ||
      this == MembershipRole.admin ||
      this == MembershipRole.treasurer;

  static MembershipRole fromValue(String? value) {
    return MembershipRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => MembershipRole.member,
    );
  }
}

enum CommunityType {
  rtRw('rt_rw', 'RT/RW'),
  cluster('cluster', 'Cluster'),
  komplek('komplek', 'Komplek'),
  apartemen('apartemen', 'Apartemen'),
  perhimpunanWarga('perhimpunan_warga', 'Perhimpunan Warga'),
  masjid('masjid', 'Masjid'),
  sekolah('sekolah', 'Sekolah'),
  komunitasLainnya('komunitas_lainnya', 'Komunitas Lainnya');

  const CommunityType(this.value, this.label);
  final String value;
  final String label;

  static CommunityType fromValue(String? value) {
    return CommunityType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CommunityType.komunitasLainnya,
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
