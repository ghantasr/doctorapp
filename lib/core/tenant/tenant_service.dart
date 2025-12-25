import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import 'tenant.dart';

class TenantException implements Exception {
  final String message;
  TenantException(this.message);

  @override
  String toString() => message;
}

class TenantService {
  final _client = SupabaseConfig.client;

  Future<List<Tenant>> fetchUserTenants(String userId) async {
    try {
      final response = await _client
          .from('user_tenant_roles')
          .select('tenant_id, tenants(id, name, logo, branding, created_at)')
          .eq('user_id', userId);

      return (response as List).map((item) {
        final tenantData = item['tenants'];
        return Tenant.fromJson(tenantData);
      }).toList();
    } catch (e) {
      throw TenantException('Failed to fetch user tenants: $e');
    }
  }

  Future<Tenant?> getTenantById(String tenantId) async {
    try {
      final response = await _client
          .from('tenants')
          .select('id, name, logo, branding, created_at')
          .eq('id', tenantId)
          .maybeSingle();

      if (response == null) return null;

      return Tenant.fromJson(response);
    } catch (e) {
      throw TenantException('Failed to fetch tenant: $e');
    }
  }

  Future<Tenant?> createTenant({
    required String name,
    String? logo,
    Map<String, dynamic>? branding,
  }) async {
    try {
      final response = await _client
          .from('tenants')
          .insert({
            'name': name,
            'logo': logo,
            'branding': branding,
          })
          .select('id, name, logo, branding, created_at')
          .single();

      return Tenant.fromJson(response);
    } catch (e) {
      throw TenantException('Failed to create tenant: $e');
    }
  }

  Future<void> createDoctorProfile({
    required String userId,
    required String tenantId,
    required String firstName,
    required String lastName,
    String? specialty,
    String? licenseNumber,
    String? email,
    String? phone,
  }) async {
    try {
      await _client.from('doctors').insert({
        'user_id': userId,
        'tenant_id': tenantId,
        'first_name': firstName,
        'last_name': lastName,
        'specialty': specialty,
        'license_number': licenseNumber,
        'email': email,
        'phone': phone,
      });
    } catch (e) {
      throw TenantException('Failed to create doctor profile: $e');
    }
  }

  Future<void> updateTenantBranding({
    required String tenantId,
    required Map<String, dynamic> branding,
  }) async {
    try {
      await _client
          .from('tenants')
          .update({'branding': branding})
          .eq('id', tenantId);
    } catch (e) {
      throw TenantException('Failed to update tenant branding: $e');
    }
  }
}

final tenantServiceProvider = Provider<TenantService>((ref) => TenantService());

class SelectedTenantNotifier extends StateNotifier<Tenant?> {
  SelectedTenantNotifier() : super(null);

  void setTenant(Tenant tenant) {
    state = tenant;
  }

  void clearTenant() {
    state = null;
  }
}

final selectedTenantProvider = StateNotifierProvider<SelectedTenantNotifier, Tenant?>((ref) {
  return SelectedTenantNotifier();
});
