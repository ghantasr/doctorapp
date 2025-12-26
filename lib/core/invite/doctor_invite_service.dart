import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';

class DoctorInviteCode {
  final String id;
  final String tenantId;
  final String code;
  final String createdBy;
  final DateTime? expiresAt;
  final int maxUses;
  final int currentUses;
  final bool isActive;
  final DateTime createdAt;

  DoctorInviteCode({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.createdBy,
    this.expiresAt,
    required this.maxUses,
    required this.currentUses,
    required this.isActive,
    required this.createdAt,
  });

  factory DoctorInviteCode.fromJson(Map<String, dynamic> json) {
    return DoctorInviteCode(
      id: json['id'],
      tenantId: json['tenant_id'],
      code: json['code'],
      createdBy: json['created_by'],
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      maxUses: json['max_uses'] ?? 1,
      currentUses: json['current_uses'] ?? 0,
      isActive: json['is_active'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isValid {
    if (!isActive) return false;
    if (currentUses >= maxUses) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  int get remainingUses => maxUses - currentUses;
}

class DoctorInviteValidation {
  final bool isValid;
  final String? tenantId;
  final String? tenantName;
  final String? errorMessage;

  DoctorInviteValidation({
    required this.isValid,
    this.tenantId,
    this.tenantName,
    this.errorMessage,
  });

  factory DoctorInviteValidation.fromJson(Map<String, dynamic> json) {
    return DoctorInviteValidation(
      isValid: json['is_valid'] ?? false,
      tenantId: json['tenant_id'],
      tenantName: json['tenant_name'],
      errorMessage: json['error_message'],
    );
  }
}

class DoctorInviteException implements Exception {
  final String message;
  DoctorInviteException(this.message);

  @override
  String toString() => message;
}

class DoctorInviteService {
  final _client = SupabaseConfig.client;

  /// Generate a new doctor invite code for a hospital
  Future<DoctorInviteCode> generateInviteCode({
    required String tenantId,
    required String createdByUserId,
    int maxUses = 1,
    Duration? expiresIn,
  }) async {
    try {
      // Generate unique code
      final codeResult = await _client.rpc('generate_doctor_invite_code');
      final code = codeResult as String;

      final data = {
        'tenant_id': tenantId,
        'code': code,
        'created_by': createdByUserId,
        'max_uses': maxUses,
        'current_uses': 0,
        'is_active': true,
      };

      if (expiresIn != null) {
        data['expires_at'] = DateTime.now().add(expiresIn).toIso8601String();
      }

      final response = await _client
          .from('doctor_invite_codes')
          .insert(data)
          .select()
          .single();

      return DoctorInviteCode.fromJson(response);
    } catch (e) {
      throw DoctorInviteException('Failed to generate invite code: $e');
    }
  }

  /// Validate a doctor invite code
  Future<DoctorInviteValidation> validateInviteCode(String code) async {
    try {
      final result = await _client.rpc(
        'validate_doctor_invite_code',
        params: {'invite_code': code},
      );

      if (result is List && result.isNotEmpty) {
        return DoctorInviteValidation.fromJson(result.first);
      }

      return DoctorInviteValidation(
        isValid: false,
        errorMessage: 'Invalid response from server',
      );
    } catch (e) {
      throw DoctorInviteException('Failed to validate invite code: $e');
    }
  }

  /// Use an invite code to join a hospital as a doctor
  Future<void> useInviteCode({
    required String code,
    required String userId,
    required String doctorId,
  }) async {
    try {
      // Validate first
      final validation = await validateInviteCode(code);
      if (!validation.isValid) {
        throw DoctorInviteException(
          validation.errorMessage ?? 'Invalid invite code',
        );
      }

      // Get the invite code record
      final inviteResponse = await _client
          .from('doctor_invite_codes')
          .select('id, tenant_id, current_uses')
          .eq('code', code)
          .single();

      final inviteId = inviteResponse['id'];
      final tenantId = inviteResponse['tenant_id'];
      final currentUses = inviteResponse['current_uses'] ?? 0;

      // Record usage
      await _client.from('doctor_invite_usage').insert({
        'invite_code_id': inviteId,
        'doctor_user_id': userId,
        'doctor_id': doctorId,
        'tenant_id': tenantId,
      });

      // Increment usage count
      await _client
          .from('doctor_invite_codes')
          .update({'current_uses': currentUses + 1})
          .eq('id', inviteId);
    } catch (e) {
      throw DoctorInviteException('Failed to use invite code: $e');
    }
  }

  /// Get all invite codes for a hospital
  Future<List<DoctorInviteCode>> getHospitalInviteCodes(String tenantId) async {
    try {
      final response = await _client
          .from('doctor_invite_codes')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DoctorInviteCode.fromJson(json))
          .toList();
    } catch (e) {
      throw DoctorInviteException('Failed to fetch invite codes: $e');
    }
  }

  /// Deactivate an invite code
  Future<void> deactivateInviteCode(String inviteCodeId) async {
    try {
      await _client
          .from('doctor_invite_codes')
          .update({'is_active': false})
          .eq('id', inviteCodeId);
    } catch (e) {
      throw DoctorInviteException('Failed to deactivate invite code: $e');
    }
  }

  /// Get doctors who joined via invite codes
  Future<List<Map<String, dynamic>>> getInvitedDoctors(String tenantId) async {
    try {
      final response = await _client
          .from('doctor_invite_usage')
          .select('''
            *,
            doctors:doctor_id (
              id,
              first_name,
              last_name,
              specialty,
              email
            )
          ''')
          .eq('tenant_id', tenantId)
          .order('used_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw DoctorInviteException('Failed to fetch invited doctors: $e');
    }
  }
}

final doctorInviteServiceProvider = Provider<DoctorInviteService>(
  (ref) => DoctorInviteService(),
);

final hospitalInviteCodesProvider = FutureProvider.family<List<DoctorInviteCode>, String>(
  (ref, tenantId) async {
    final service = ref.watch(doctorInviteServiceProvider);
    return await service.getHospitalInviteCodes(tenantId);
  },
);
