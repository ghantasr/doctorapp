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
