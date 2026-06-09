import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/phone_number_formatter.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/app_repository.dart';

class AuthState {
  const AuthState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => profile != null;

  AuthState copyWith({
    UserProfile? profile,
    bool clearProfile = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      profile: clearProfile ? null : profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState(isLoading: true)) {
    _restoreSession();
  }

  final AppRepository _repository;

  SupabaseClient? get _client =>
      AppConfig.isSupabaseConfigured ? Supabase.instance.client : null;

  Future<void> _restoreSession() async {
    final user = _client?.auth.currentUser;
    if (user == null) {
      state = const AuthState();
      return;
    }
    await _loadProfile(user.id);
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (_client == null) {
        final profile = _demoLogin(identifier, password);
        state = AuthState(profile: profile);
        return true;
      }

      final type = PhoneNumberFormatter.detectLoginIdentifierType(identifier);
      if (type == LoginIdentifierType.unknown) {
        throw const FormatException(
          'Masukkan email atau nomor handphone Indonesia yang valid.',
        );
      }

      String email = identifier.trim().toLowerCase();
      if (type == LoginIdentifierType.phone) {
        if (!PhoneNumberFormatter.isValidIndonesianPhoneNumber(identifier)) {
          throw const FormatException(
            'Nomor handphone Indonesia belum valid.',
          );
        }
        final phone =
            PhoneNumberFormatter.normalizeIndonesianPhoneNumber(identifier);
        final result = await _client!.rpc(
          'get_email_by_phone',
          params: {'normalized_phone': phone},
        );
        if (result == null || result.toString().isEmpty) {
          throw const AuthDisplayException('Nomor handphone belum terdaftar.');
        }
        email = result.toString();
      }

      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const AuthDisplayException('Login belum berhasil.');
      }
      await _loadProfile(response.user!.id);
      return true;
    } on AuthException catch (error) {
      final message = error.message.toLowerCase().contains('invalid login')
          ? 'Password yang Anda masukkan salah.'
          : 'Login gagal. Periksa kembali email dan password Anda.';
      state = AuthState(errorMessage: message);
      return false;
    } on AuthDisplayException catch (error) {
      state = AuthState(errorMessage: error.message);
      return false;
    } on FormatException catch (error) {
      state = AuthState(errorMessage: error.message);
      return false;
    } catch (_) {
      state = const AuthState(
        errorMessage: 'Terjadi kendala saat login. Silakan coba lagi.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final normalized =
          PhoneNumberFormatter.normalizeIndonesianPhoneNumber(phoneNumber);
      if (_client == null) {
        DemoDataStore.instance.registerMember(
          fullName: fullName,
          email: email,
          phoneNumber: normalized,
          password: password,
        );
        state = const AuthState();
        return true;
      }
      await _client!.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone_number': normalized,
          'role': 'member',
        },
      );
      state = const AuthState();
      return true;
    } on AuthException catch (error) {
      final lower = error.message.toLowerCase();
      final message = lower.contains('already') || lower.contains('unique')
          ? 'Email atau nomor handphone sudah terdaftar.'
          : 'Pendaftaran belum berhasil. Silakan periksa kembali data Anda.';
      state = AuthState(errorMessage: message);
      return false;
    } on FormatException catch (error) {
      state = AuthState(errorMessage: error.message);
      return false;
    } on DemoRegistrationException catch (error) {
      state = AuthState(errorMessage: error.message);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (_client != null) {
        await _client!.auth.resetPasswordForEmail(
          email.trim().toLowerCase(),
          redirectTo: Uri.base.resolve('/login').toString(),
        );
      }
      state = const AuthState();
      return true;
    } on AuthException {
      state = const AuthState(
        errorMessage: 'Tautan reset belum dapat dikirim. Periksa email Anda.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _client?.auth.signOut();
    state = const AuthState();
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final rows = await _repository.getProfiles();
      final profile = rows.firstWhere((item) => item.id == userId);
      state = AuthState(profile: profile);
    } catch (_) {
      state = const AuthState(
        errorMessage: 'Profil pengguna tidak ditemukan.',
      );
    }
  }

  UserProfile _demoLogin(String identifier, String password) {
    final type = PhoneNumberFormatter.detectLoginIdentifierType(identifier);
    String lookup = identifier.trim().toLowerCase();
    if (type == LoginIdentifierType.phone) {
      lookup = PhoneNumberFormatter.normalizeIndonesianPhoneNumber(identifier);
    }
    final profiles = DemoDataStore.instance.profiles.map(UserProfile.fromJson);
    try {
      final profile = profiles.firstWhere(
        (profile) =>
            profile.email.toLowerCase() == lookup ||
            profile.phoneNumber == lookup,
      );
      if (!DemoDataStore.instance.passwordMatches(profile.id, password)) {
        throw const AuthDisplayException(
          'Password yang Anda masukkan salah.',
        );
      }
      return profile;
    } on AuthDisplayException {
      rethrow;
    } catch (_) {
      if (type == LoginIdentifierType.phone) {
        throw const AuthDisplayException('Nomor handphone belum terdaftar.');
      }
      throw const AuthDisplayException('Email belum terdaftar.');
    }
  }
}

class AuthDisplayException implements Exception {
  const AuthDisplayException(this.message);
  final String message;
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AppRepository());
});
