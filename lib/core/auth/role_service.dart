import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../auth/auth_service.dart';
import '../../shared/widgets/hospital_selector.dart';

class RoleService {
  final _client = SupabaseConfig.client;

  /// Check if current user is admin in a specific tenant
  Future<bool> isUserAdmin({
    required String userId,
    required String tenantId,
  }) async {
    try {
      // Try using RPC function first
      final result = await _client.rpc(
        'is_user_admin',
        params: {
          'p_user_id': userId,
          'p_tenant_id': tenantId,
        },
      );
      return result as bool? ?? false;
    } catch (e) {
      // Fallback to direct query if RPC function doesn't exist
      try {
        final response = await _client
            .from('user_tenant_roles')
            .select('role')
            .eq('user_id', userId)
            .eq('tenant_id', tenantId)
            .eq('role', 'admin')
            .maybeSingle();
        
        return response != null;
      } catch (e2) {
        return false;
      }
    }
  }

  /// Get user's role in a specific tenant
  Future<String?> getUserRole({
    required String userId,
    required String tenantId,
  }) async {
    try {
      final response = await _client
          .from('user_tenant_roles')
          .select('role')
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      return response?['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Suspend a doctor
  Future<bool> suspendDoctor({
    required String doctorId,
    required String suspendedBy,
    required String tenantId,
  }) async {
    try {
      final result = await _client.rpc(
        'suspend_doctor',
        params: {
          'p_doctor_id': doctorId,
          'p_suspended_by': suspendedBy,
          'p_tenant_id': tenantId,
        },
      );
      return result as bool? ?? false;
    } catch (e) {
      throw Exception('Failed to suspend doctor: $e');
    }
  }

  /// Activate a doctor
  Future<bool> activateDoctor({
    required String doctorId,
    required String activatedBy,
    required String tenantId,
  }) async {
    try {
      final result = await _client.rpc(
        'activate_doctor',
        params: {
          'p_doctor_id': doctorId,
          'p_activated_by': activatedBy,
          'p_tenant_id': tenantId,
        },
      );
      return result as bool? ?? false;
    } catch (e) {
      throw Exception('Failed to activate doctor: $e');
    }
  }

  /// Check if a doctor is suspended
  Future<bool> isDoctorSuspended(String doctorId) async {
    try {
      final result = await _client.rpc(
        'is_doctor_suspended',
        params: {'p_doctor_id': doctorId},
      );
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
}

final roleServiceProvider = Provider<RoleService>((ref) => RoleService());

/// Provider to check if current user is admin in current tenant
final isCurrentUserAdminProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  
  if (userId == null) return false;
  
  // Get current tenant from hospital selector
  final currentHospital = ref.watch(currentHospitalProvider);
  if (currentHospital == null) return false;
  
  final roleService = ref.watch(roleServiceProvider);
  return await roleService.isUserAdmin(
    userId: userId,
    tenantId: currentHospital.id,
  );
});

/// Provider to get current user's role in current tenant
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  
  if (userId == null) return null;
  
  final currentHospital = ref.watch(currentHospitalProvider);
  if (currentHospital == null) return null;
  
  final roleService = ref.watch(roleServiceProvider);
  return await roleService.getUserRole(
    userId: userId,
    tenantId: currentHospital.id,
  );
});
