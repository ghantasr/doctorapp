import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';
import '../tenant/tenant_service.dart';

class InviteService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Generate a simple invite code from tenant ID (first 8 chars)
  String generateInviteCode(String tenantId) {
    return tenantId.substring(0, 8).toUpperCase();
  }

  // Find tenant by invite code (stored text column preferred; falls back to legacy prefix lookup)
  Future<String?> findTenantByInviteCode(String inviteCode) async {
    // Primary: use a text column `invite_code` so we avoid casting UUIDs
    try {
      final response = await _client
          .from('tenants')
          .select('id')
          .eq('invite_code', inviteCode)
          .maybeSingle();

      if (response != null) {
        return response['id'] as String;
      }
    } catch (_) {
      // If the column doesn't exist yet, fall back below
    }

    // Fallback: legacy prefix match on UUID string (will only work if DB allows ilike on a text-cast column)
    try {
      final response = await _client
          .from('tenants')
          .select('id')
          .ilike('id', '$inviteCode%')
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return response['id'] as String;
    } catch (_) {
      return null;
    }
  }
}

final inviteServiceProvider = Provider<InviteService>((ref) {
  return InviteService();
});

final inviteCodeProvider = Provider<String?>((ref) {
  final tenant = ref.watch(selectedTenantProvider);
  if (tenant == null) return null;
  
  final inviteService = ref.watch(inviteServiceProvider);
  return inviteService.generateInviteCode(tenant.id);
});
