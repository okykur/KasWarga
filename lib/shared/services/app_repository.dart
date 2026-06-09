import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../models/app_models.dart';

class AppRepository {
  AppRepository()
      : _client =
            AppConfig.isSupabaseConfigured ? Supabase.instance.client : null;

  final SupabaseClient? _client;
  final _demo = DemoDataStore.instance;

  bool get isDemoMode => _client == null;

  Future<List<Community>> getCommunities() async {
    if (isDemoMode) return _demo.communities.map(Community.fromJson).toList();
    final rows = await _client!.from('communities').select().order('name');
    return rows.map(Community.fromJson).toList();
  }

  Future<void> saveCommunity({
    String? id,
    required String name,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'province': province.trim(),
      'postal_code': postalCode.trim(),
      'is_active': isActive,
    };
    if (isDemoMode) {
      _demo.upsert(_demo.communities, id, payload);
      return;
    }
    if (id == null) {
      await _client!.from('communities').insert(payload);
    } else {
      await _client!.from('communities').update(payload).eq('id', id);
    }
  }

  Future<List<UserProfile>> getProfiles() async {
    if (isDemoMode) return _demo.profiles.map(UserProfile.fromJson).toList();
    final rows = await _client!.from('profiles').select().order('full_name');
    return rows.map(UserProfile.fromJson).toList();
  }

  Future<void> updateProfileRole({
    required String profileId,
    required UserRole role,
    String? communityId,
  }) async {
    if (isDemoMode) {
      _demo.updateById(_demo.profiles, profileId, {
        'role': role.value,
        'community_id': communityId,
      });
      return;
    }
    await _client!.from('profiles').update({
      'role': role.value,
      'community_id': communityId,
    }).eq('id', profileId);
  }

  Future<List<PaymentAccount>> getPaymentAccounts({
    required String communityId,
    bool activeOnly = false,
  }) async {
    if (isDemoMode) {
      return _demo.paymentAccounts
          .where(
            (row) =>
                row['community_id'] == communityId &&
                (!activeOnly || row['is_active'] == true),
          )
          .map(PaymentAccount.fromJson)
          .toList();
    }
    dynamic query = _client!
        .from('payment_accounts')
        .select()
        .eq('community_id', communityId);
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('is_default', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(
          PaymentAccount.fromJson,
        )
        .toList();
  }

  Future<void> savePaymentAccount({
    String? id,
    required String communityId,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
    String? branchName,
    String? instruction,
    required bool isDefault,
    required bool isActive,
    required String userId,
  }) async {
    final payload = <String, dynamic>{
      'community_id': communityId,
      'bank_name': bankName.trim(),
      'account_number': accountNumber.trim(),
      'account_holder_name': accountHolderName.trim(),
      'branch_name': _nullable(branchName),
      'payment_instruction': _nullable(instruction),
      'is_default': isDefault,
      'is_active': isActive,
      'created_by': userId,
    };
    if (isDemoMode) {
      final savedId = _demo.upsert(_demo.paymentAccounts, id, payload);
      if (isDefault && isActive) {
        for (final account in _demo.paymentAccounts) {
          if (account['community_id'] == communityId &&
              account['id'] != savedId) {
            account['is_default'] = false;
          }
        }
      }
      return;
    }
    if (id == null) {
      await _client!.from('payment_accounts').insert(payload);
    } else {
      await _client!.from('payment_accounts').update(payload).eq('id', id);
    }
  }

  Future<void> deactivatePaymentAccount(String id) async {
    if (isDemoMode) {
      _demo.updateById(
        _demo.paymentAccounts,
        id,
        {'is_active': false, 'is_default': false},
      );
      return;
    }
    await _client!.from('payment_accounts').update({
      'is_active': false,
      'is_default': false,
    }).eq('id', id);
  }

  Future<List<CommunityMember>> getMembers(String communityId) async {
    if (isDemoMode) {
      return _demo.members
          .where((row) => row['community_id'] == communityId)
          .map(CommunityMember.fromJson)
          .toList();
    }
    final rows = await _client!
        .from('community_members')
        .select()
        .eq('community_id', communityId)
        .order('full_name');
    return rows.map(CommunityMember.fromJson).toList();
  }

  Future<void> saveMember({
    String? id,
    required String communityId,
    String? userId,
    required String fullName,
    required String phoneNumber,
    required String block,
    required String houseNumber,
    required int familyCount,
    required String status,
  }) async {
    final payload = <String, dynamic>{
      'community_id': communityId,
      'user_id': userId,
      'full_name': fullName.trim(),
      'phone_number': phoneNumber,
      'house_block': block.trim(),
      'house_number': houseNumber.trim(),
      'family_count': familyCount,
      'status': status,
    };
    if (isDemoMode) {
      _demo.upsert(_demo.members, id, payload);
      return;
    }
    if (id == null) {
      await _client!.from('community_members').insert(payload);
    } else {
      await _client!.from('community_members').update(payload).eq('id', id);
    }
  }

  Future<List<Due>> getDues(String communityId) async {
    if (isDemoMode) {
      return _demo.dues
          .where((row) => row['community_id'] == communityId)
          .map(Due.fromJson)
          .toList();
    }
    final rows = await _client!
        .from('dues')
        .select()
        .eq('community_id', communityId)
        .order('year', ascending: false)
        .order('month', ascending: false);
    return rows.map(Due.fromJson).toList();
  }

  Future<void> createDue({
    required String communityId,
    required String title,
    String? description,
    required int month,
    required int year,
    required double amount,
    required DateTime dueDate,
  }) async {
    final payload = <String, dynamic>{
      'community_id': communityId,
      'title': title.trim(),
      'description': _nullable(description),
      'month': month,
      'year': year,
      'amount': amount,
      'due_date': _isoDate(dueDate),
    };
    if (isDemoMode) {
      final id = _demo.upsert(_demo.dues, null, payload);
      for (final member in _demo.members.where(
        (row) =>
            row['community_id'] == communityId && row['status'] == 'active',
      )) {
        _demo.upsert(_demo.bills, null, {
          'dues_id': id,
          'community_id': communityId,
          'member_id': member['id'],
          'amount': amount,
          'status': 'unpaid',
          'dues': {'title': title, 'month': month, 'year': year},
          'community_members': {'full_name': member['full_name']},
        });
      }
      return;
    }
    final row =
        await _client!.from('dues').insert(payload).select('id').single();
    await _client.rpc(
      'generate_bills_for_due',
      params: {'target_due_id': row['id']},
    );
  }

  Future<List<Bill>> getBills({
    required String communityId,
    String? memberId,
    BillStatus? status,
  }) async {
    if (isDemoMode) {
      return _demo.bills
          .where(
            (row) =>
                row['community_id'] == communityId &&
                (memberId == null || row['member_id'] == memberId) &&
                (status == null || row['status'] == status.value),
          )
          .map(Bill.fromJson)
          .toList();
    }
    dynamic query = _client!
        .from('bills')
        .select('*, dues(title, month, year), community_members(full_name)')
        .eq('community_id', communityId);
    if (memberId != null) query = query.eq('member_id', memberId);
    if (status != null) query = query.eq('status', status.value);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Bill.fromJson)
        .toList();
  }

  Future<String?> getMemberIdForUser(String userId) async {
    if (isDemoMode) {
      return _demo.members
          .where((row) => row['user_id'] == userId)
          .map((row) => row['id'] as String)
          .firstOrNull;
    }
    final row = await _client!
        .from('community_members')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<void> submitPayment({
    required String billId,
    required String paymentAccountId,
    required DateTime paymentDate,
    required Uint8List proofBytes,
    required String fileExtension,
    required String communityId,
    required String userId,
  }) async {
    String proofPath;
    if (isDemoMode) {
      proofPath = 'demo/$billId.$fileExtension';
      _demo.updateById(_demo.bills, billId, {
        'selected_payment_account_id': paymentAccountId,
        'payment_date': _isoDate(paymentDate),
        'payment_method': 'bank_transfer',
        'payment_proof_url': proofPath,
        'status': 'waiting_verification',
        'admin_note': null,
      });
      return;
    }

    proofPath =
        '$communityId/$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client!.storage.from(AppConstants.paymentProofBucket).uploadBinary(
          proofPath,
          proofBytes,
          fileOptions: FileOptions(
            contentType:
                fileExtension == 'jpg' ? 'image/jpeg' : 'image/$fileExtension',
            upsert: false,
          ),
        );
    await _client.from('bills').update({
      'selected_payment_account_id': paymentAccountId,
      'payment_date': _isoDate(paymentDate),
      'payment_method': 'bank_transfer',
      'payment_proof_url': proofPath,
      'status': 'waiting_verification',
      'admin_note': null,
    }).eq('id', billId);
  }

  Future<void> verifyBill({
    required String billId,
    required bool approved,
    String? note,
  }) async {
    if (!approved && (note == null || note.trim().isEmpty)) {
      throw ArgumentError('Alasan penolakan wajib diisi.');
    }
    if (isDemoMode) {
      _demo.updateById(_demo.bills, billId, {
        'status': approved ? 'paid' : 'rejected',
        'admin_note': approved ? null : note!.trim(),
        'verified_at': DateTime.now().toIso8601String(),
      });
      return;
    }
    await _client!.rpc(
      'verify_bill_payment',
      params: {
        'target_bill_id': billId,
        'approved': approved,
        'rejection_note': note,
      },
    );
  }

  Future<String?> getSignedStorageUrl({
    required String bucket,
    required String? path,
  }) async {
    if (path == null || path.isEmpty || isDemoMode) return null;
    return _client!.storage.from(bucket).createSignedUrl(path, 300);
  }

  Future<List<Expense>> getExpenses(String communityId) async {
    if (isDemoMode) {
      return _demo.expenses
          .where((row) => row['community_id'] == communityId)
          .map(Expense.fromJson)
          .toList();
    }
    final rows = await _client!
        .from('expenses')
        .select()
        .eq('community_id', communityId)
        .order('expense_date', ascending: false);
    return rows.map(Expense.fromJson).toList();
  }

  Future<void> saveExpense({
    required String communityId,
    required String title,
    String? description,
    required double amount,
    required DateTime expenseDate,
    required String userId,
    Uint8List? receiptBytes,
    String? receiptExtension,
  }) async {
    String? receiptPath;
    if (!isDemoMode && receiptBytes != null && receiptExtension != null) {
      receiptPath =
          '$communityId/$userId/${DateTime.now().millisecondsSinceEpoch}.$receiptExtension';
      await _client!.storage
          .from(AppConstants.expenseReceiptBucket)
          .uploadBinary(
            receiptPath,
            receiptBytes,
            fileOptions: FileOptions(
              contentType: receiptExtension == 'jpg'
                  ? 'image/jpeg'
                  : 'image/$receiptExtension',
            ),
          );
    }
    final payload = <String, dynamic>{
      'community_id': communityId,
      'title': title.trim(),
      'description': _nullable(description),
      'amount': amount,
      'expense_date': _isoDate(expenseDate),
      'receipt_image_url': receiptPath,
      'created_by': userId,
    };
    if (isDemoMode) {
      _demo.upsert(_demo.expenses, null, payload);
    } else {
      await _client!.from('expenses').insert(payload);
    }
  }

  Future<List<Announcement>> getAnnouncements(String communityId) async {
    if (isDemoMode) {
      return _demo.announcements
          .where((row) => row['community_id'] == communityId)
          .map(Announcement.fromJson)
          .toList();
    }
    final rows = await _client!
        .from('announcements')
        .select()
        .eq('community_id', communityId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Announcement.fromJson).toList();
  }

  Future<void> saveAnnouncement({
    String? id,
    required String communityId,
    required String title,
    required String content,
    required bool isPinned,
    required String userId,
  }) async {
    final payload = <String, dynamic>{
      'community_id': communityId,
      'title': title.trim(),
      'content': content.trim(),
      'is_pinned': isPinned,
      'created_by': userId,
    };
    if (isDemoMode) {
      _demo.upsert(_demo.announcements, id, payload);
    } else if (id == null) {
      await _client!.from('announcements').insert(payload);
    } else {
      await _client!.from('announcements').update(payload).eq('id', id);
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    if (isDemoMode) {
      _demo.announcements.removeWhere((row) => row['id'] == id);
    } else {
      await _client!.from('announcements').delete().eq('id', id);
    }
  }

  Future<CashSummary> getCashSummary(String communityId) async {
    if (isDemoMode) {
      final paid = _demo.bills
          .where(
            (row) =>
                row['community_id'] == communityId && row['status'] == 'paid',
          )
          .fold<double>(
              0, (sum, row) => sum + (row['amount'] as num).toDouble());
      final unpaid = _demo.bills
          .where(
            (row) =>
                row['community_id'] == communityId && row['status'] != 'paid',
          )
          .fold<double>(
              0, (sum, row) => sum + (row['amount'] as num).toDouble());
      final expenses = _demo.expenses
          .where((row) => row['community_id'] == communityId)
          .fold<double>(
              0, (sum, row) => sum + (row['amount'] as num).toDouble());
      return CashSummary(
        totalPaid: paid,
        totalUnpaid: unpaid,
        totalExpenses: expenses,
      );
    }
    final response = await _client!.rpc('get_community_cash_summary');
    final row = response is List ? response.first : response;
    return CashSummary.fromJson(Map<String, dynamic>.from(row as Map));
  }

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class DemoDataStore {
  DemoDataStore._();
  static final instance = DemoDataStore._();

  final communities = <Map<String, dynamic>>[
    {
      'id': AppConstants.demoCommunityId,
      'name': 'Warga Harmoni RT 05',
      'address': 'Jl. Melati Raya No. 5',
      'city': 'Bandung',
      'province': 'Jawa Barat',
      'postal_code': '40123',
      'is_active': true,
    },
  ];

  final profiles = <Map<String, dynamic>>[
    {
      'id': '22222222-2222-2222-2222-222222222222',
      'full_name': 'Super Admin KasWarga',
      'email': 'superadmin@kaswarga.local',
      'phone_number': '+628111111110',
      'role': 'super_admin',
      'community_id': null,
    },
    {
      'id': '33333333-3333-3333-3333-333333333333',
      'full_name': 'Budi Bendahara',
      'email': 'admin@kaswarga.local',
      'phone_number': '+628111111111',
      'role': 'admin',
      'community_id': AppConstants.demoCommunityId,
    },
    for (var index = 1; index <= 3; index++)
      {
        'id': '44444444-4444-4444-4444-44444444444$index',
        'full_name': 'Warga Demo $index',
        'email': 'member$index@kaswarga.local',
        'phone_number': '+62811111111${index + 1}',
        'role': 'member',
        'community_id': AppConstants.demoCommunityId,
      },
  ];

  final paymentAccounts = <Map<String, dynamic>>[
    {
      'id': '55555555-5555-5555-5555-555555555551',
      'community_id': AppConstants.demoCommunityId,
      'bank_name': 'BCA',
      'account_number': '1234567890',
      'account_holder_name': 'Bendahara RT 05',
      'branch_name': 'Bandung',
      'payment_instruction':
          'Transfer sesuai nominal tagihan, lalu upload bukti pembayaran.',
      'is_default': true,
      'is_active': true,
    },
    {
      'id': '55555555-5555-5555-5555-555555555552',
      'community_id': AppConstants.demoCommunityId,
      'bank_name': 'Mandiri',
      'account_number': '9876543210',
      'account_holder_name': 'Kas Warga RT 05',
      'branch_name': null,
      'payment_instruction':
          'Cantumkan nama dan nomor rumah pada berita transfer.',
      'is_default': false,
      'is_active': true,
    },
  ];

  final members = <Map<String, dynamic>>[
    for (var index = 1; index <= 3; index++)
      {
        'id': '44444444-4444-4444-4444-44444444444$index',
        'community_id': AppConstants.demoCommunityId,
        'user_id': '44444444-4444-4444-4444-44444444444$index',
        'full_name': 'Warga Demo $index',
        'phone_number': '+62811111111${index + 1}',
        'house_block': 'A',
        'house_number': index.toString().padLeft(2, '0'),
        'family_count': index + 1,
        'status': 'active',
      },
  ];

  final dues = <Map<String, dynamic>>[
    {
      'id': '66666666-6666-6666-6666-666666666666',
      'community_id': AppConstants.demoCommunityId,
      'title': 'Iuran Bulanan',
      'description': 'Kebersihan, keamanan, dan kegiatan warga.',
      'month': DateTime.now().month,
      'year': DateTime.now().year,
      'amount': 150000,
      'due_date': DateTime(
        DateTime.now().year,
        DateTime.now().month,
        10,
      ).toIso8601String(),
    },
  ];

  final bills = <Map<String, dynamic>>[
    for (var index = 1; index <= 3; index++)
      {
        'id': '77777777-7777-7777-7777-77777777777$index',
        'dues_id': '66666666-6666-6666-6666-666666666666',
        'community_id': AppConstants.demoCommunityId,
        'member_id': '44444444-4444-4444-4444-44444444444$index',
        'amount': 150000,
        'status': index == 1
            ? 'unpaid'
            : index == 2
                ? 'waiting_verification'
                : 'paid',
        'selected_payment_account_id':
            index == 1 ? null : '55555555-5555-5555-5555-555555555551',
        'payment_date': index == 1 ? null : DateTime.now().toIso8601String(),
        'payment_method': index == 1 ? null : 'bank_transfer',
        'payment_proof_url': index == 1 ? null : 'demo/proof-$index.jpg',
        'dues': {
          'title': 'Iuran Bulanan',
          'month': DateTime.now().month,
          'year': DateTime.now().year,
        },
        'community_members': {'full_name': 'Warga Demo $index'},
      },
  ];

  final expenses = <Map<String, dynamic>>[
    {
      'id': '88888888-8888-8888-8888-888888888888',
      'community_id': AppConstants.demoCommunityId,
      'title': 'Perbaikan lampu jalan',
      'description': 'Penggantian dua lampu area gerbang.',
      'amount': 75000,
      'expense_date':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'receipt_image_url': null,
    },
  ];

  final announcements = <Map<String, dynamic>>[
    {
      'id': '99999999-9999-9999-9999-999999999999',
      'community_id': AppConstants.demoCommunityId,
      'title': 'Kerja Bakti Minggu Pagi',
      'content':
          'Mari berkumpul pukul 07.00 di balai warga. Peralatan kebersihan disiapkan panitia.',
      'is_pinned': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  String upsert(
    List<Map<String, dynamic>> target,
    String? id,
    Map<String, dynamic> payload,
  ) {
    final resolvedId =
        id ?? '${DateTime.now().microsecondsSinceEpoch}'.padLeft(36, '0');
    final index = target.indexWhere((row) => row['id'] == resolvedId);
    if (index >= 0) {
      target[index] = {...target[index], ...payload, 'id': resolvedId};
    } else {
      target.add({...payload, 'id': resolvedId});
    }
    return resolvedId;
  }

  void updateById(
    List<Map<String, dynamic>> target,
    String id,
    Map<String, dynamic> payload,
  ) {
    final index = target.indexWhere((row) => row['id'] == id);
    if (index >= 0) target[index] = {...target[index], ...payload};
  }
}
