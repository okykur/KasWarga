import 'package:flutter_test/flutter_test.dart';
import 'package:kaswarga/core/constants/app_constants.dart';
import 'package:kaswarga/features/auth/presentation/auth_controller.dart';
import 'package:kaswarga/shared/services/app_repository.dart';

void main() {
  final repository = AppRepository();
  final store = DemoDataStore.instance;

  test('user dapat join langsung melalui kode komunitas', () async {
    const userId = '22222222-2222-2222-2222-222222222222';
    final result = await repository.joinCommunityByCode(
      userId: userId,
      code: 'GARDENIA-2026',
    );

    expect(result, 'active');
    final memberships = await repository.getUserMemberships(userId);
    expect(
      memberships.any(
        (item) =>
            item.communityId == AppConstants.demoSecondCommunityId &&
            item.role == MembershipRole.member,
      ),
      isTrue,
    );
  });

  test('user dapat menerima invitation dengan email yang sama', () async {
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final profile = store.registerMember(
      fullName: 'Penerima Undangan',
      email: 'invite$suffix@example.com',
      phoneNumber: '+6288${suffix.substring(suffix.length - 9)}',
      password: 'rahasia123',
    );
    final invitation = store.createInvitation(
      communityId: AppConstants.demoCommunityId,
      invitedBy: '33333333-3333-3333-3333-333333333333',
      email: profile.email,
      role: MembershipRole.member,
    );

    await repository.acceptInvitation(
      token: invitation.token,
      userId: profile.id,
      userEmail: profile.email,
    );

    final memberships = await repository.getUserMemberships(profile.id);
    expect(memberships.single.communityId, AppConstants.demoCommunityId);
    expect(memberships.single.joinedVia, 'invitation_email');
  });

  test('role berbeda per komunitas dan switcher memilih tenant aktif',
      () async {
    final memberships = await repository.getUserMemberships(
      '44444444-4444-4444-4444-444444444441',
    );
    expect(memberships.length, 2);
    expect(
      memberships.map((item) => item.role).toSet(),
      {MembershipRole.member, MembershipRole.admin},
    );

    final state = AuthState(
      memberships: memberships,
      selectedCommunityId: AppConstants.demoSecondCommunityId,
    );
    expect(state.selectedCommunityId, AppConstants.demoSecondCommunityId);
    expect(state.selectedMembership?.role, MembershipRole.admin);
    expect(state.canManageSelectedCommunity, isTrue);
  });

  test('limit plan Free mengizinkan member selama kuota tersedia', () async {
    expect(
      await repository.canAddMember(AppConstants.demoCommunityId),
      isTrue,
    );
    expect(
      await repository.canAddAdmin(AppConstants.demoCommunityId),
      isFalse,
    );
  });
}
