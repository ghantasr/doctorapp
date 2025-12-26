import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';
import '../auth/auth_service.dart';
import '../../shared/widgets/hospital_selector.dart';

class DoctorProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String specialty;
  final String licenseNumber;
  final String? phone;
  final String? email;
  final String tenantId;
  final String userId;
  final bool isSuspended;
  final DateTime? suspendedAt;

  DoctorProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialty,
    required this.licenseNumber,
    this.phone,
    this.email,
    required this.tenantId,
    required this.userId,
    this.isSuspended = false,
    this.suspendedAt,
  });

  String get fullName => '$firstName $lastName';

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      specialty: json['specialty'] as String? ?? 'General',
      licenseNumber: json['license_number'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      tenantId: json['tenant_id'] as String,
      userId: json['user_id'] as String,
      isSuspended: json['is_suspended'] as bool? ?? false,
      suspendedAt: json['suspended_at'] != null
          ? DateTime.parse(json['suspended_at'])
          : null,
    );
  }
}

class DoctorService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<DoctorProfile?> getDoctorProfile({
    required String userId,
    required String tenantId,
  }) async {
    try {
      final response = await _client
          .from('doctors')
          .select('*')
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (response == null) return null;

      return DoctorProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch doctor profile: $e');
    }
  }

  Future<void> updateDoctorProfile({
    required String doctorId,
    required String firstName,
    required String lastName,
    required String specialty,
    required String licenseNumber,
    String? phone,
    String? email,
  }) async {
    try {
      await _client.from('doctors').update({
        'first_name': firstName,
        'last_name': lastName,
        'specialty': specialty,
        'license_number': licenseNumber,
        'phone': phone,
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', doctorId);
    } catch (e) {
      throw Exception('Failed to update doctor profile: $e');
    }
  }
}

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final doctorProfileProvider = FutureProvider<DoctorProfile?>((ref) async {
  final doctorService = ref.watch(doctorServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final currentHospital = ref.watch(currentHospitalProvider);

  final userId = authService.currentUser?.id;
  if (userId == null || currentHospital == null) {
    return null;
  }

  return doctorService.getDoctorProfile(
    userId: userId,
    tenantId: currentHospital.id,
  );
});
