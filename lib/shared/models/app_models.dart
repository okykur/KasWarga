import '../../core/constants/app_constants.dart';

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());
double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.communityId,
  });

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final String? communityId;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        role: UserRole.fromValue(json['role'] as String?),
        communityId: json['community_id'] as String?,
      );
}

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.isActive,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final bool isActive;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        province: json['province'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

class PaymentAccount {
  const PaymentAccount({
    required this.id,
    required this.communityId,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    this.branchName,
    this.paymentInstruction,
    required this.isDefault,
    required this.isActive,
  });

  final String id;
  final String communityId;
  final String bankName;
  final String accountNumber;
  final String accountHolderName;
  final String? branchName;
  final String? paymentInstruction;
  final bool isDefault;
  final bool isActive;

  factory PaymentAccount.fromJson(Map<String, dynamic> json) => PaymentAccount(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountHolderName: json['account_holder_name'] as String? ?? '',
        branchName: json['branch_name'] as String?,
        paymentInstruction: json['payment_instruction'] as String?,
        isDefault: json['is_default'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class CommunityMember {
  const CommunityMember({
    required this.id,
    required this.communityId,
    this.userId,
    required this.fullName,
    required this.phoneNumber,
    required this.houseBlock,
    required this.houseNumber,
    required this.familyCount,
    required this.status,
  });

  final String id;
  final String communityId;
  final String? userId;
  final String fullName;
  final String phoneNumber;
  final String houseBlock;
  final String houseNumber;
  final int familyCount;
  final String status;

  factory CommunityMember.fromJson(Map<String, dynamic> json) =>
      CommunityMember(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        userId: json['user_id'] as String?,
        fullName: json['full_name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        houseBlock: json['house_block'] as String? ?? '',
        houseNumber: json['house_number'] as String? ?? '',
        familyCount: json['family_count'] as int? ?? 1,
        status: json['status'] as String? ?? 'active',
      );
}

class Due {
  const Due({
    required this.id,
    required this.communityId,
    required this.title,
    this.description,
    required this.month,
    required this.year,
    required this.amount,
    required this.dueDate,
  });

  final String id;
  final String communityId;
  final String title;
  final String? description;
  final int month;
  final int year;
  final double amount;
  final DateTime dueDate;

  factory Due.fromJson(Map<String, dynamic> json) => Due(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        month: json['month'] as int,
        year: json['year'] as int,
        amount: _double(json['amount']),
        dueDate: _date(json['due_date']) ?? DateTime.now(),
      );
}

class Bill {
  const Bill({
    required this.id,
    required this.duesId,
    required this.communityId,
    required this.memberId,
    required this.amount,
    required this.status,
    this.selectedPaymentAccountId,
    this.paymentDate,
    this.paymentMethod,
    this.paymentProofUrl,
    this.adminNote,
    this.verifiedBy,
    this.verifiedAt,
    this.title,
    this.dueMonth,
    this.dueYear,
    this.memberName,
  });

  final String id;
  final String duesId;
  final String communityId;
  final String memberId;
  final double amount;
  final BillStatus status;
  final String? selectedPaymentAccountId;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? paymentProofUrl;
  final String? adminNote;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? title;
  final int? dueMonth;
  final int? dueYear;
  final String? memberName;

  factory Bill.fromJson(Map<String, dynamic> json) {
    final dues = json['dues'] as Map<String, dynamic>?;
    final member = json['community_members'] as Map<String, dynamic>?;
    return Bill(
      id: json['id'] as String,
      duesId: json['dues_id'] as String,
      communityId: json['community_id'] as String,
      memberId: json['member_id'] as String,
      amount: _double(json['amount']),
      status: BillStatus.fromValue(json['status'] as String?),
      selectedPaymentAccountId:
          json['selected_payment_account_id'] as String?,
      paymentDate: _date(json['payment_date']),
      paymentMethod: json['payment_method'] as String?,
      paymentProofUrl: json['payment_proof_url'] as String?,
      adminNote: json['admin_note'] as String?,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: _date(json['verified_at']),
      title: dues?['title'] as String?,
      dueMonth: dues?['month'] as int?,
      dueYear: dues?['year'] as int?,
      memberName: member?['full_name'] as String?,
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.communityId,
    required this.title,
    this.description,
    required this.amount,
    required this.expenseDate,
    this.receiptImageUrl,
  });

  final String id;
  final String communityId;
  final String title;
  final String? description;
  final double amount;
  final DateTime expenseDate;
  final String? receiptImageUrl;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        amount: _double(json['amount']),
        expenseDate: _date(json['expense_date']) ?? DateTime.now(),
        receiptImageUrl: json['receipt_image_url'] as String?,
      );
}

class Announcement {
  const Announcement({
    required this.id,
    required this.communityId,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.createdAt,
  });

  final String id;
  final String communityId;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        isPinned: json['is_pinned'] as bool? ?? false,
        createdAt: _date(json['created_at']) ?? DateTime.now(),
      );
}

class CashSummary {
  const CashSummary({
    required this.totalPaid,
    required this.totalUnpaid,
    required this.totalExpenses,
  });

  final double totalPaid;
  final double totalUnpaid;
  final double totalExpenses;
  double get balance => totalPaid - totalExpenses;

  factory CashSummary.fromJson(Map<String, dynamic> json) => CashSummary(
        totalPaid: _double(json['total_paid']),
        totalUnpaid: _double(json['total_unpaid']),
        totalExpenses: _double(json['total_expenses']),
      );
}
