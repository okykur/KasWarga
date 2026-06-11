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
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
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
    required this.type,
    required this.communityCode,
    required this.isCodeJoinEnabled,
    required this.requireAdminApproval,
    required this.isActive,
    this.createdBy,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final CommunityType type;
  final String communityCode;
  final bool isCodeJoinEnabled;
  final bool requireAdminApproval;
  final bool isActive;
  final String? createdBy;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        province: json['province'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        type: CommunityType.fromValue(json['type'] as String?),
        communityCode: json['community_code'] as String? ?? '',
        isCodeJoinEnabled: json['is_code_join_enabled'] as bool? ?? true,
        requireAdminApproval: json['require_admin_approval'] as bool? ?? true,
        isActive: json['is_active'] as bool? ?? true,
        createdBy: json['created_by'] as String?,
      );
}

class CommunityMembership {
  const CommunityMembership({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedVia,
    required this.community,
  });

  final String id;
  final String communityId;
  final String userId;
  final MembershipRole role;
  final String status;
  final String joinedVia;
  final Community community;

  bool get isActive => status == 'active';
  bool get canManage => role.canManage;

  factory CommunityMembership.fromJson(Map<String, dynamic> json) {
    final communityJson = json['communities'] as Map<String, dynamic>? ??
        json['community'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return CommunityMembership(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      userId: json['user_id'] as String,
      role: MembershipRole.fromValue(json['role'] as String?),
      status: json['status'] as String? ?? 'pending',
      joinedVia: json['joined_via'] as String? ?? 'community_code',
      community: Community.fromJson({
        ...communityJson,
        'id': communityJson['id'] ?? json['community_id'],
      }),
    );
  }
}

class CommunityInvitation {
  const CommunityInvitation({
    required this.id,
    required this.communityId,
    required this.invitedEmail,
    required this.role,
    required this.token,
    required this.status,
    required this.expiresAt,
    this.invitedFullName,
    this.invitedPhoneNumber,
    this.communityName,
  });

  final String id;
  final String communityId;
  final String invitedEmail;
  final String? invitedPhoneNumber;
  final String? invitedFullName;
  final MembershipRole role;
  final String token;
  final String status;
  final DateTime expiresAt;
  final String? communityName;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  factory CommunityInvitation.fromJson(Map<String, dynamic> json) {
    final community = json['communities'] as Map<String, dynamic>?;
    return CommunityInvitation(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      invitedEmail: json['invited_email'] as String? ?? '',
      invitedPhoneNumber: json['invited_phone_number'] as String?,
      invitedFullName: json['invited_full_name'] as String?,
      role: MembershipRole.fromValue(json['role'] as String?),
      token: json['invitation_token'] as String,
      status: json['status'] as String? ?? 'pending',
      expiresAt: _date(json['expires_at']) ?? DateTime.now(),
      communityName: community?['name'] as String?,
    );
  }
}

class CommunityJoinRequest {
  const CommunityJoinRequest({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.status,
    this.requestNote,
    this.requesterName,
    this.requesterEmail,
  });

  final String id;
  final String communityId;
  final String userId;
  final String status;
  final String? requestNote;
  final String? requesterName;
  final String? requesterEmail;

  factory CommunityJoinRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CommunityJoinRequest(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'pending',
      requestNote: json['request_note'] as String?,
      requesterName: profile?['full_name'] as String?,
      requesterEmail: profile?['email'] as String?,
    );
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.code,
    required this.priceMonthly,
    this.maxMembers,
    this.maxAdmins,
    this.maxCommunities,
    required this.features,
  });

  final String id;
  final String name;
  final String code;
  final double priceMonthly;
  final int? maxMembers;
  final int? maxAdmins;
  final int? maxCommunities;
  final Map<String, dynamic> features;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        priceMonthly: _double(json['price_monthly']),
        maxMembers: json['max_members'] as int?,
        maxAdmins: json['max_admins'] as int?,
        maxCommunities: json['max_communities'] as int?,
        features: Map<String, dynamic>.from(
          json['features'] as Map? ?? const {},
        ),
      );
}

class CommunitySubscription {
  const CommunitySubscription({
    required this.id,
    required this.communityId,
    required this.status,
    required this.plan,
    this.trialEndsAt,
  });

  final String id;
  final String communityId;
  final String status;
  final SubscriptionPlan plan;
  final DateTime? trialEndsAt;

  factory CommunitySubscription.fromJson(Map<String, dynamic> json) =>
      CommunitySubscription(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        status: json['status'] as String? ?? 'trial',
        trialEndsAt: _date(json['trial_ends_at']),
        plan: SubscriptionPlan.fromJson(
          Map<String, dynamic>.from(
            json['subscription_plans'] as Map? ?? const {},
          ),
        ),
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
        fullName: json['full_name_in_community'] as String? ??
            json['full_name'] as String? ??
            '',
        phoneNumber: json['phone_number_in_community'] as String? ??
            json['phone_number'] as String? ??
            '',
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
    final member = json['community_member_details'] as Map<String, dynamic>? ??
        json['community_members'] as Map<String, dynamic>?;
    return Bill(
      id: json['id'] as String,
      duesId: json['dues_id'] as String,
      communityId: json['community_id'] as String,
      memberId: json['member_id'] as String,
      amount: _double(json['amount']),
      status: BillStatus.fromValue(json['status'] as String?),
      selectedPaymentAccountId: json['selected_payment_account_id'] as String?,
      paymentDate: _date(json['payment_date']),
      paymentMethod: json['payment_method'] as String?,
      paymentProofUrl: json['payment_proof_url'] as String?,
      adminNote: json['admin_note'] as String?,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: _date(json['verified_at']),
      title: dues?['title'] as String?,
      dueMonth: dues?['month'] as int?,
      dueYear: dues?['year'] as int?,
      memberName: member?['full_name_in_community'] as String? ??
          member?['full_name'] as String?,
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
