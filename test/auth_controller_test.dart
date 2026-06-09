import 'package:flutter_test/flutter_test.dart';
import 'package:kaswarga/features/auth/presentation/auth_controller.dart';
import 'package:kaswarga/shared/services/app_repository.dart';

void main() {
  test('akun demo hasil registrasi dapat login dengan email dan nomor HP',
      () async {
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final email = 'warga$suffix@example.com';
    final phone = '+6287${suffix.substring(suffix.length - 9)}';
    const password = 'rahasia123';
    final controller = AuthController(AppRepository());
    await Future<void>.delayed(Duration.zero);

    final registered = await controller.register(
      fullName: 'Warga Baru',
      email: email,
      phoneNumber: phone,
      password: password,
    );

    expect(registered, isTrue);
    expect(
      DemoDataStore.instance.members.any(
        (member) => member['phone_number'] == phone,
      ),
      isTrue,
    );

    final emailLogin = await controller.login(
      identifier: email,
      password: password,
    );
    expect(emailLogin, isTrue);
    expect(controller.state.profile?.email, email);

    await controller.logout();
    final phoneLogin = await controller.login(
      identifier: phone,
      password: password,
    );
    expect(phoneLogin, isTrue);
    expect(controller.state.profile?.phoneNumber, phone);

    await controller.logout();
    final wrongPassword = await controller.login(
      identifier: email,
      password: 'password-salah',
    );
    expect(wrongPassword, isFalse);
    expect(
      controller.state.errorMessage,
      'Password yang Anda masukkan salah.',
    );

    controller.dispose();
  });
}
