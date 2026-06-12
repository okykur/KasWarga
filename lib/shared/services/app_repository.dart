import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/community_code.dart';
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

  Future<List<CommunityMembership>> getUserMemberships(String userId) async {
    if (isDemoMode) {
      return _demo.memberships
          .where(
        (row) => row['user_id'] == userId && row['status'] == 'active',
      )
          .map((row) {
        final community = _demo.communities.firstWhere(
          (item) => item['id'] == row['community_id'],
        );
        return CommunityMembership.fromJson({
          ...row,
          'communities': community,
        });
      }).toList();
    }
    final rows = await _client!
        .from('community_memberships')
        .select('*, communities(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at');
    return rows.map(CommunityMembership.fromJson).toList();
  }

  Future<bool> isPlatformSuperAdmin(String userId) async {
    if (isDemoMode) return _demo.platformAdminIds.contains(userId);
    final result = await _client!.rpc(
      'is_platform_super_admin',
      params: {'user_id': userId},
    );
    return result == true;
  }

  Future<CommunityMembership> createCommunity({
    required String userId,
    required String fullName,
    required String phoneNumber,
    required String name,
    required CommunityType type,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required String communityCode,
  }) async {
    final code = CommunityCode.normalize(communityCode);
    if (!CommunityCode.isValid(code)) {
      throw const TenantException('Kode komunitas belum valid.');
    }
    if (isDemoMode) {
      return _demo.createCommunity(
        userId: userId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        name: name,
        type: type,
        address: address,
        city: city,
        province: province,
        postalCode: postalCode,
        communityCode: code,
      );
    }
    final row = await _client!.rpc(
      'create_community_with_owner',
      params: {
        'community_name': name.trim(),
        'community_type': type.value,
        'community_address': address.trim(),
        'community_city': city.trim(),
        'community_province': province.trim(),
        'community_postal_code': postalCode.trim(),
        'requested_code': code,
      },
    );
    final membershipId = row.toString();
    final memberships = await getUserMemberships(userId);
    return memberships.firstWhere((item) => item.id == membershipId);
  }

  Future<Community?> findCommunityByCode(String code) async {
    final normalized = CommunityCode.normalize(code);
    if (isDemoMode) {
      final row = _demo.communities
          .where((item) => item['community_code'] == normalized)
          .firstOrNull;
      return row == null ? null : Community.fromJson(row);
    }
    final row = await _client!.rpc(
      'get_community_by_code',
      params: {'requested_code': normalized},
    );
    if (row == null || row is List && row.isEmpty) return null;
    final data = row is List ? row.first : row;
    return Community.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<String> joinCommunityByCode({
    required String userId,
    required String code,
    String? note,
  }) async {
    if (isDemoMode) {
      return _demo.joinCommunityByCode(
        userId: userId,
        code: CommunityCode.normalize(code),
        note: note,
      );
    }
    final result = await _client!.rpc(
      'join_community_by_code',
      params: {
        'requested_code': CommunityCode.normalize(code),
        'request_note': _nullable(note),
      },
    );
    return result.toString();
  }

  Future<void> updateCommunitySettings({
    required String communityId,
    required String name,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required String communityCode,
    required bool isCodeJoinEnabled,
    required bool requireAdminApproval,
  }) async {
    final payload = {
      'name': name.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'province': province.trim(),
      'postal_code': postalCode.trim(),
      'community_code': CommunityCode.normalize(communityCode),
      'is_code_join_enabled': isCodeJoinEnabled,
      'require_admin_approval': requireAdminApproval,
    };
    if (isDemoMode) {
      if (_demo.communities.any(
        (item) =>
            item['community_code'] == payload['community_code'] &&
            item['id'] != communityId,
      )) {
        throw const TenantException('Kode komunitas sudah digunakan.');
      }
      _demo.updateById(_demo.communities, communityId, payload);
      return;
    }
    await _client!.from('communities').update(payload).eq('id', communityId);
  }

  Future<List<CommunityInvitation>> getInvitations(
    String communityId,
  ) async {
    if (isDemoMode) {
      return _demo.invitations
          .where((row) => row['community_id'] == communityId)
          .map(CommunityInvitation.fromJson)
          .toList();
    }
    final rows = await _client!
        .from('community_invitations')
        .select()
        .eq('community_id', communityId)
        .order('created_at', ascending: false);
    return rows.map(CommunityInvitation.fromJson).toList();
  }

  Future<CommunityInvitation> createInvitation({
    required String communityId,
    required String invitedBy,
    required String email,
    String? fullName,
    String? phoneNumber,
    required MembershipRole role,
  }) async {
    if (isDemoMode) {
      return _demo.createInvitation(
        communityId: communityId,
        invitedBy: invitedBy,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
      );
    }
    final row = await _client!
        .from('community_invitations')
        .insert({
          'community_id': communityId,
          'invited_email': email.trim().toLowerCase(),
          'invited_full_name': _nullable(fullName),
          'invited_phone_number': _nullable(phoneNumber),
          'role': role.value,
          'invitation_token': _secureToken(),
          'invited_by': invitedBy,
        })
        .select()
        .single();
    return CommunityInvitation.fromJson(row);
  }

  Future<void> cancelInvitation(String invitationId) async {
    if (isDemoMode) {
      _demo.updateById(
        _demo.invitations,
        invitationId,
        {'status': 'cancelled'},
      );
      return;
    }
    await _client!
        .from('community_invitations')
        .update({'status': 'cancelled'}).eq('id', invitationId);
  }

  Future<void> resendInvitation(String invitationId) async {
    final payload = {
      'invitation_token': _secureToken(),
      'status': 'pending',
      'expires_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    };
    if (isDemoMode) {
      _demo.updateById(_demo.invitations, invitationId, payload);
      return;
    }
    await _client!
        .from('community_invitations')
        .update(payload)
        .eq('id', invitationId);
  }

  Future<CommunityInvitation?> getInvitationByToken(String token) async {
    if (isDemoMode) {
      final row = _demo.invitations
          .where((item) => item['invitation_token'] == token)
          .firstOrNull;
      if (row == null) return null;
      final community = _demo.communities.firstWhere(
        (item) => item['id'] == row['community_id'],
      );
      return CommunityInvitation.fromJson({
        ...row,
        'communities': {'name': community['name']},
      });
    }
    final row = await _client!.rpc(
      'get_invitation_by_token',
      params: {'requested_token': token},
    );
    if (row == null || row is List && row.isEmpty) return null;
    final data = row is List ? row.first : row;
    return CommunityInvitation.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> acceptInvitation({
    required String token,
    required String userId,
    required String userEmail,
  }) async {
    if (isDemoMode) {
      _demo.acceptInvitation(
        token: token,
        userId: userId,
        userEmail: userEmail,
      );
      return;
    }
    await _client!.rpc(
      'accept_community_invitation',
      params: {'requested_token': token},
    );
  }

  Future<List<CommunityJoinRequest>> getJoinRequests(
    String communityId,
  ) async {
    if (isDemoMode) {
      return _demo.joinRequests
          .where((row) => row['community_id'] == communityId)
          .map((row) {
        final profile = _demo.profiles.firstWhere(
          (item) => item['id'] == row['user_id'],
        );
        return CommunityJoinRequest.fromJson({
          ...row,
          'profiles': profile,
        });
      }).toList();
    }
    final rows = await _client!
        .from('community_join_requests')
        .select('*, profiles(full_name, email)')
        .eq('community_id', communityId)
        .order('created_at', ascending: false);
    return rows.map(CommunityJoinRequest.fromJson).toList();
  }

  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approved,
    String? rejectionReason,
  }) async {
    if (!approved &&
        (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      throw const TenantException('Alasan penolakan wajib diisi.');
    }
    if (isDemoMode) {
      _demo.reviewJoinRequest(
        requestId: requestId,
        approved: approved,
        rejectionReason: rejectionReason,
      );
      return;
    }
    await _client!.rpc(
      'review_community_join_request',
      params: {
        'target_request_id': requestId,
        'approved': approved,
        'rejection_reason': _nullable(rejectionReason),
      },
    );
  }

  Future<CommunitySubscription?> getCommunitySubscription(
    String communityId,
  ) async {
    if (isDemoMode) {
      final row = _demo.communitySubscriptions
          .where((item) => item['community_id'] == communityId)
          .firstOrNull;
      if (row == null) return null;
      final plan = _demo.subscriptionPlans.firstWhere(
        (item) => item['id'] == row['plan_id'],
      );
      return CommunitySubscription.fromJson({
        ...row,
        'subscription_plans': plan,
      });
    }
    final row = await _client!
        .from('community_subscriptions')
        .select('*, subscription_plans(*)')
        .eq('community_id', communityId)
        .maybeSingle();
    return row == null ? null : CommunitySubscription.fromJson(row);
  }

  Future<bool> canAddMember(String communityId) async {
    if (!isDemoMode) {
      return await _client!.rpc(
            'can_add_member',
            params: {'target_community_id': communityId},
          ) ==
          true;
    }
    final subscription = await getCommunitySubscription(communityId);
    final limit = subscription?.plan.maxMembers;
    if (limit == null) return true;
    final count = _demo.memberships
        .where(
          (item) =>
              item['community_id'] == communityId && item['status'] == 'active',
        )
        .length;
    return count < limit;
  }

  Future<bool> canAddAdmin(String communityId) async {
    if (!isDemoMode) {
      return await _client!.rpc(
            'can_add_admin',
            params: {'target_community_id': communityId},
          ) ==
          true;
    }
    final subscription = await getCommunitySubscription(communityId);
    final limit = subscription?.plan.maxAdmins;
    if (limit == null) return true;
    final count = _demo.memberships
        .where(
          (item) =>
              item['community_id'] == communityId &&
              item['status'] == 'active' &&
              item['role'] != 'member',
        )
        .length;
    return count < limit;
  }

  Future<bool> canCreateCommunity(String userId) async {
    if (!isDemoMode) {
      return await _client!.rpc(
            'can_create_community',
            params: {'target_user_id': userId},
          ) ==
          true;
    }
    return _demo.memberships
            .where(
              (item) =>
                  item['user_id'] == userId &&
                  item['role'] == 'owner' &&
                  item['status'] == 'active',
            )
            .length <
        3;
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
      'type': CommunityType.komunitasLainnya.value,
      'community_code': CommunityCode.generate(name),
      'is_code_join_enabled': true,
      'require_admin_approval': true,
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
      return _demo.memberDetails
          .where((row) => row['community_id'] == communityId)
          .map(CommunityMember.fromJson)
          .toList();
    }
    final rows = await _client!
        .from('community_member_details')
        .select()
        .eq('community_id', communityId)
        .order('full_name_in_community');
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
    String? membershipId;
    if (userId != null) {
      if (isDemoMode) {
        membershipId = _demo.memberships
            .where(
              (item) =>
                  item['community_id'] == communityId &&
                  item['user_id'] == userId,
            )
            .map((item) => item['id'] as String)
            .firstOrNull;
      } else {
        final membership = await _client!
            .from('community_memberships')
            .select('id')
            .eq('community_id', communityId)
            .eq('user_id', userId)
            .maybeSingle();
        membershipId = membership?['id'] as String?;
      }
    }
    final payload = <String, dynamic>{
      'community_id': communityId,
      'user_id': userId,
      'membership_id': membershipId,
      'full_name_in_community': fullName.trim(),
      'phone_number_in_community': phoneNumber,
      'house_block': block.trim(),
      'house_number': houseNumber.trim(),
      'family_count': familyCount,
      'status': status,
    };
    if (isDemoMode) {
      _demo.upsert(_demo.memberDetails, id, payload);
      return;
    }
    if (id == null) {
      await _client!.from('community_member_details').insert(payload);
    } else {
      await _client!
          .from('community_member_details')
          .update(payload)
          .eq('id', id);
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

  Future<void> saveDue({
    String? id,
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
      final duplicate = _demo.dues.any(
        (row) =>
            row['id'] != id &&
            row['community_id'] == communityId &&
            row['title'] == title.trim() &&
            row['month'] == month &&
            row['year'] == year,
      );
      if (duplicate) {
        throw const TenantException(
          'Iuran dengan judul dan periode tersebut sudah ada.',
        );
      }
      final savedId = _demo.upsert(_demo.dues, id, payload);
      if (id != null) {
        for (final bill in _demo.bills.where(
          (row) =>
              row['dues_id'] == id &&
              (row['status'] == 'unpaid' || row['status'] == 'rejected'),
        )) {
          bill['amount'] = amount;
          bill['dues'] = {
            'title': title.trim(),
            'month': month,
            'year': year,
          };
        }
        return;
      }
      for (final member in _demo.memberDetails.where(
        (row) =>
            row['community_id'] == communityId && row['status'] == 'active',
      )) {
        _demo.upsert(_demo.bills, null, {
          'dues_id': savedId,
          'community_id': communityId,
          'member_id': member['id'],
          'amount': amount,
          'status': 'unpaid',
          'dues': {'title': title, 'month': month, 'year': year},
          'community_member_details': {
            'full_name_in_community': member['full_name_in_community'],
          },
        });
      }
      return;
    }
    if (id != null) {
      await _client!.rpc(
        'update_due_and_open_bills',
        params: {
          'target_due_id': id,
          'new_title': title.trim(),
          'new_description': _nullable(description),
          'new_month': month,
          'new_year': year,
          'new_amount': amount,
          'new_due_date': _isoDate(dueDate),
        },
      );
      return;
    }
    final row =
        await _client!.from('dues').insert(payload).select('id').single();
    await _client.rpc(
      'generate_bills_for_due',
      params: {'target_due_id': row['id']},
    );
  }

  Future<void> createDue({
    required String communityId,
    required String title,
    String? description,
    required int month,
    required int year,
    required double amount,
    required DateTime dueDate,
  }) =>
      saveDue(
        communityId: communityId,
        title: title,
        description: description,
        month: month,
        year: year,
        amount: amount,
        dueDate: dueDate,
      );

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
        .select(
          '*, dues(title, month, year), '
          'community_member_details(full_name_in_community)',
        )
        .eq('community_id', communityId);
    if (memberId != null) query = query.eq('member_id', memberId);
    if (status != null) query = query.eq('status', status.value);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Bill.fromJson)
        .toList();
  }

  Future<String?> getMemberIdForUser(
    String userId, {
    required String communityId,
  }) async {
    if (isDemoMode) {
      return _demo.memberDetails
          .where(
            (row) =>
                row['user_id'] == userId && row['community_id'] == communityId,
          )
          .map((row) => row['id'] as String)
          .firstOrNull;
    }
    final row = await _client!
        .from('community_member_details')
        .select('id')
        .eq('user_id', userId)
        .eq('community_id', communityId)
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
    String? id,
    required String communityId,
    required String title,
    String? description,
    required double amount,
    required DateTime expenseDate,
    required String userId,
    Uint8List? receiptBytes,
    String? receiptExtension,
    String? existingReceiptPath,
  }) async {
    String? receiptPath = existingReceiptPath;
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
      if (id == null) 'created_by': userId,
    };
    if (isDemoMode) {
      _demo.upsert(_demo.expenses, id, payload);
    } else if (id == null) {
      await _client!.from('expenses').insert(payload);
    } else {
      await _client!.from('expenses').update(payload).eq('id', id);
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
    final response = await _client!.rpc(
      'get_community_cash_summary',
      params: {'target_community_id': communityId},
    );
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

  static String _secureToken() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final random = Random.secure();
    return List.generate(
      48,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

class DemoDataStore {
  DemoDataStore._();
  static final instance = DemoDataStore._();

  final demoPasswords = <String, String>{
    '22222222-2222-2222-2222-222222222222': 'password123',
    '33333333-3333-3333-3333-333333333333': 'password123',
    '44444444-4444-4444-4444-444444444441': 'password123',
    '44444444-4444-4444-4444-444444444442': 'password123',
    '44444444-4444-4444-4444-444444444443': 'password123',
  };

  final platformAdminIds = <String>{
    '22222222-2222-2222-2222-222222222222',
  };

  final communities = <Map<String, dynamic>>[
    {
      'id': AppConstants.demoCommunityId,
      'name': 'Cluster Melati RT 05',
      'type': 'cluster',
      'address': 'Jl. Melati Raya No. 5',
      'city': 'Bandung',
      'province': 'Jawa Barat',
      'postal_code': '40123',
      'community_code': 'MELATI-RT05',
      'is_code_join_enabled': true,
      'require_admin_approval': true,
      'is_active': true,
      'created_by': '33333333-3333-3333-3333-333333333333',
    },
    {
      'id': AppConstants.demoSecondCommunityId,
      'name': 'Perhimpunan Warga Gardenia',
      'type': 'perhimpunan_warga',
      'address': 'Jl. Gardenia Utama No. 8',
      'city': 'Bekasi',
      'province': 'Jawa Barat',
      'postal_code': '17145',
      'community_code': 'GARDENIA-2026',
      'is_code_join_enabled': true,
      'require_admin_approval': false,
      'is_active': true,
      'created_by': '44444444-4444-4444-4444-444444444443',
    },
  ];

  final profiles = <Map<String, dynamic>>[
    {
      'id': '22222222-2222-2222-2222-222222222222',
      'full_name': 'Super Admin KasWarga',
      'email': 'superadmin@kaswarga.local',
      'phone_number': '+628111111110',
    },
    {
      'id': '33333333-3333-3333-3333-333333333333',
      'full_name': 'Budi Bendahara',
      'email': 'admin@kaswarga.local',
      'phone_number': '+628111111111',
    },
    for (var index = 1; index <= 3; index++)
      {
        'id': '44444444-4444-4444-4444-44444444444$index',
        'full_name': 'Warga Demo $index',
        'email': 'member$index@kaswarga.local',
        'phone_number': '+62811111111${index + 1}',
      },
  ];

  final memberships = <Map<String, dynamic>>[
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
      'community_id': AppConstants.demoCommunityId,
      'user_id': '33333333-3333-3333-3333-333333333333',
      'role': 'owner',
      'status': 'active',
      'joined_via': 'created_community',
    },
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
      'community_id': AppConstants.demoCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444441',
      'role': 'member',
      'status': 'active',
      'joined_via': 'community_code',
    },
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
      'community_id': AppConstants.demoCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444442',
      'role': 'treasurer',
      'status': 'active',
      'joined_via': 'invitation_email',
    },
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
      'community_id': AppConstants.demoSecondCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444443',
      'role': 'owner',
      'status': 'active',
      'joined_via': 'created_community',
    },
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
      'community_id': AppConstants.demoSecondCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444441',
      'role': 'admin',
      'status': 'active',
      'joined_via': 'community_code',
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

  final memberDetails = <Map<String, dynamic>>[
    for (var index = 1; index <= 2; index++)
      {
        'id': '44444444-4444-4444-4444-44444444444$index',
        'community_id': AppConstants.demoCommunityId,
        'user_id': '44444444-4444-4444-4444-44444444444$index',
        'membership_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa${index + 1}',
        'full_name_in_community': 'Warga Demo $index',
        'phone_number_in_community': '+62811111111${index + 1}',
        'house_block': 'A',
        'house_number': index.toString().padLeft(2, '0'),
        'family_count': index + 1,
        'status': 'active',
      },
    {
      'id': '44444444-4444-4444-4444-444444444443',
      'community_id': AppConstants.demoSecondCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444443',
      'membership_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
      'full_name_in_community': 'Warga Demo 3',
      'phone_number_in_community': '+628111111114',
      'house_block': 'G',
      'house_number': '01',
      'family_count': 2,
      'status': 'active',
    },
    {
      'id': '44444444-4444-4444-4444-444444444445',
      'community_id': AppConstants.demoSecondCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444441',
      'membership_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
      'full_name_in_community': 'Warga Demo 1',
      'phone_number_in_community': '+628111111112',
      'house_block': 'G',
      'house_number': '02',
      'family_count': 3,
      'status': 'active',
    },
  ];

  final subscriptionPlans = <Map<String, dynamic>>[
    {
      'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
      'name': 'Free',
      'code': 'free',
      'price_monthly': 0,
      'max_members': 30,
      'max_admins': 2,
      'max_communities': 1,
      'features': {
        'iuran_bulanan': true,
        'upload_bukti': true,
        'pengumuman': true,
        'laporan_csv': true,
      },
    },
    {
      'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
      'name': 'Pro',
      'code': 'pro',
      'price_monthly': 99000,
      'max_members': 500,
      'max_admins': 10,
      'max_communities': 5,
      'features': {'semua_fitur_free': true, 'dukungan_prioritas': true},
    },
  ];

  final communitySubscriptions = <Map<String, dynamic>>[
    {
      'id': 'cccccccc-cccc-cccc-cccc-ccccccccccc1',
      'community_id': AppConstants.demoCommunityId,
      'plan_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
      'status': 'active',
    },
    {
      'id': 'cccccccc-cccc-cccc-cccc-ccccccccccc2',
      'community_id': AppConstants.demoSecondCommunityId,
      'plan_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
      'status': 'active',
    },
  ];

  final invitations = <Map<String, dynamic>>[
    {
      'id': 'dddddddd-dddd-dddd-dddd-ddddddddddd1',
      'community_id': AppConstants.demoCommunityId,
      'invited_email': 'calonwarga@kaswarga.local',
      'invited_full_name': 'Calon Warga',
      'invited_phone_number': null,
      'role': 'member',
      'invitation_token': 'demo-undangan-melati-2026',
      'status': 'pending',
      'expires_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'invited_by': '33333333-3333-3333-3333-333333333333',
    },
  ];

  final joinRequests = <Map<String, dynamic>>[
    {
      'id': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
      'community_id': AppConstants.demoCommunityId,
      'user_id': '44444444-4444-4444-4444-444444444443',
      'request_note': 'Saya tinggal di Blok C.',
      'status': 'pending',
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

  UserProfile registerMember({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (profiles.any(
      (profile) =>
          (profile['email'] as String).toLowerCase() == normalizedEmail,
    )) {
      throw const DemoRegistrationException(
        'Email sudah terdaftar. Silakan gunakan email lain.',
      );
    }
    if (profiles.any((profile) => profile['phone_number'] == phoneNumber)) {
      throw const DemoRegistrationException(
        'Nomor handphone sudah terdaftar.',
      );
    }

    final userId = _newDemoId();
    final profile = <String, dynamic>{
      'id': userId,
      'full_name': fullName.trim(),
      'email': normalizedEmail,
      'phone_number': phoneNumber,
    };
    profiles.add(profile);
    demoPasswords[userId] = password;

    return UserProfile.fromJson(profile);
  }

  CommunityMembership createCommunity({
    required String userId,
    required String fullName,
    required String phoneNumber,
    required String name,
    required CommunityType type,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required String communityCode,
  }) {
    if (communities.any(
      (item) => item['community_code'] == communityCode,
    )) {
      throw const TenantException('Kode komunitas sudah digunakan.');
    }
    final communityId = _newDemoId();
    final membershipId = _newDemoId();
    final community = <String, dynamic>{
      'id': communityId,
      'name': name.trim(),
      'type': type.value,
      'address': address.trim(),
      'city': city.trim(),
      'province': province.trim(),
      'postal_code': postalCode.trim(),
      'community_code': communityCode,
      'is_code_join_enabled': true,
      'require_admin_approval': true,
      'is_active': true,
      'created_by': userId,
    };
    final membership = <String, dynamic>{
      'id': membershipId,
      'community_id': communityId,
      'user_id': userId,
      'role': 'owner',
      'status': 'active',
      'joined_via': 'created_community',
    };
    communities.add(community);
    memberships.add(membership);
    memberDetails.add({
      'id': _newDemoId(),
      'community_id': communityId,
      'user_id': userId,
      'membership_id': membershipId,
      'full_name_in_community': fullName,
      'phone_number_in_community': phoneNumber,
      'house_block': null,
      'house_number': null,
      'family_count': 1,
      'status': 'active',
    });
    communitySubscriptions.add({
      'id': _newDemoId(),
      'community_id': communityId,
      'plan_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
      'status': 'trial',
      'trial_ends_at':
          DateTime.now().add(const Duration(days: 14)).toIso8601String(),
    });
    return CommunityMembership.fromJson({
      ...membership,
      'communities': community,
    });
  }

  String joinCommunityByCode({
    required String userId,
    required String code,
    String? note,
  }) {
    final community =
        communities.where((item) => item['community_code'] == code).firstOrNull;
    if (community == null) {
      throw const TenantException('Kode komunitas tidak ditemukan.');
    }
    if (community['is_active'] != true) {
      throw const TenantException('Komunitas ini sedang tidak aktif.');
    }
    if (community['is_code_join_enabled'] != true) {
      throw const TenantException(
        'Komunitas ini tidak menerima pendaftaran melalui kode.',
      );
    }
    final existing = memberships.where(
      (item) =>
          item['community_id'] == community['id'] && item['user_id'] == userId,
    );
    if (existing.isNotEmpty) {
      throw const TenantException(
        'Anda sudah tergabung dalam komunitas ini.',
      );
    }
    final membershipId = _newDemoId();
    final needsApproval = community['require_admin_approval'] == true;
    memberships.add({
      'id': membershipId,
      'community_id': community['id'],
      'user_id': userId,
      'role': 'member',
      'status': needsApproval ? 'pending' : 'active',
      'joined_via': 'community_code',
    });
    if (needsApproval) {
      joinRequests.add({
        'id': _newDemoId(),
        'community_id': community['id'],
        'user_id': userId,
        'request_note': note,
        'status': 'pending',
      });
      return 'pending';
    }
    _createMemberDetail(
      communityId: community['id'] as String,
      userId: userId,
      membershipId: membershipId,
    );
    return 'active';
  }

  CommunityInvitation createInvitation({
    required String communityId,
    required String invitedBy,
    required String email,
    String? fullName,
    String? phoneNumber,
    required MembershipRole role,
  }) {
    final invitation = <String, dynamic>{
      'id': _newDemoId(),
      'community_id': communityId,
      'invited_email': email.trim().toLowerCase(),
      'invited_full_name': fullName,
      'invited_phone_number': phoneNumber,
      'role': role.value,
      'invitation_token': AppRepository._secureToken(),
      'status': 'pending',
      'expires_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'invited_by': invitedBy,
    };
    invitations.add(invitation);
    return CommunityInvitation.fromJson(invitation);
  }

  void acceptInvitation({
    required String token,
    required String userId,
    required String userEmail,
  }) {
    final invitation = invitations
        .where((item) => item['invitation_token'] == token)
        .firstOrNull;
    if (invitation == null) {
      throw const TenantException('Undangan tidak valid.');
    }
    if (invitation['status'] != 'pending') {
      throw TenantException(
        invitation['status'] == 'accepted'
            ? 'Undangan sudah diterima.'
            : 'Undangan sudah dibatalkan.',
      );
    }
    if (DateTime.parse(invitation['expires_at'] as String)
        .isBefore(DateTime.now())) {
      throw const TenantException('Undangan sudah kedaluwarsa.');
    }
    if ((invitation['invited_email'] as String).toLowerCase() !=
        userEmail.toLowerCase()) {
      throw const TenantException(
        'Undangan ini dikirim ke email berbeda.',
      );
    }
    if (memberships.any(
      (item) =>
          item['community_id'] == invitation['community_id'] &&
          item['user_id'] == userId,
    )) {
      throw const TenantException(
        'Anda sudah tergabung dalam komunitas ini.',
      );
    }
    final membershipId = _newDemoId();
    memberships.add({
      'id': membershipId,
      'community_id': invitation['community_id'],
      'user_id': userId,
      'role': invitation['role'],
      'status': 'active',
      'joined_via': 'invitation_email',
    });
    _createMemberDetail(
      communityId: invitation['community_id'] as String,
      userId: userId,
      membershipId: membershipId,
    );
    invitation['status'] = 'accepted';
    invitation['accepted_by'] = userId;
    invitation['accepted_at'] = DateTime.now().toIso8601String();
  }

  void reviewJoinRequest({
    required String requestId,
    required bool approved,
    String? rejectionReason,
  }) {
    final request = joinRequests.firstWhere((item) => item['id'] == requestId);
    request['status'] = approved ? 'approved' : 'rejected';
    request['reviewed_at'] = DateTime.now().toIso8601String();
    request['rejection_reason'] = approved ? null : rejectionReason;
    final membership = memberships.firstWhere(
      (item) =>
          item['community_id'] == request['community_id'] &&
          item['user_id'] == request['user_id'],
    );
    if (approved) {
      membership['status'] = 'active';
      _createMemberDetail(
        communityId: request['community_id'] as String,
        userId: request['user_id'] as String,
        membershipId: membership['id'] as String,
      );
    } else {
      membership['status'] = 'rejected';
    }
  }

  void _createMemberDetail({
    required String communityId,
    required String userId,
    required String membershipId,
  }) {
    if (memberDetails.any(
      (item) =>
          item['community_id'] == communityId && item['user_id'] == userId,
    )) {
      return;
    }
    final profile = profiles.firstWhere((item) => item['id'] == userId);
    memberDetails.add({
      'id': _newDemoId(),
      'community_id': communityId,
      'user_id': userId,
      'membership_id': membershipId,
      'full_name_in_community': profile['full_name'],
      'phone_number_in_community': profile['phone_number'],
      'house_block': null,
      'house_number': null,
      'family_count': 1,
      'status': 'active',
    });
  }

  bool passwordMatches(String userId, String password) {
    return demoPasswords[userId] == password;
  }

  String _newDemoId() {
    final value = DateTime.now().microsecondsSinceEpoch.toString();
    return value.padLeft(36, '0');
  }

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

class DemoRegistrationException implements Exception {
  const DemoRegistrationException(this.message);
  final String message;
}

class TenantException implements Exception {
  const TenantException(this.message);
  final String message;

  @override
  String toString() => message;
}
