import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';
import 'user_role.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithOTP(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
    } on AuthException catch (e) {
      throw AuthException('Failed to send OTP: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to send OTP: $e');
    }
  }

  Future<void> verifyOTP(String email, String token) async {
    try {
      await _client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: token,
      );
    } on AuthException catch (e) {
      throw AuthException('Failed to verify OTP: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to verify OTP: $e');
    }
  }

  Future<List<UserTenantRole>> fetchUserTenantRoles(String userId) async {
    try {
      final response = await _client
          .from('user_tenant_roles')
          .select('user_id, tenant_id, role, created_at')
          .eq('user_id', userId);

      return (response as List)
          .map((json) => UserTenantRole.fromJson(json))
          .toList();
    } catch (e) {
      throw AuthException('Failed to fetch user tenant roles: $e');
    }
  }

  Future<UserTenantRole?> getUserRoleForTenant({
    required String userId,
    required String tenantId,
  }) async {
    try {
      final response = await _client
          .from('user_tenant_roles')
          .select('user_id, tenant_id, role, created_at')
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (response == null) return null;

      return UserTenantRole.fromJson(response);
    } catch (e) {
      throw AuthException('Failed to fetch user role: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out: $e');
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
