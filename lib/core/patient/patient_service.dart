import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../auth/auth_service.dart';
import '../doctor/doctor_service.dart';
import '../../shared/widgets/hospital_selector.dart';

class PatientInfo {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final DateTime createdAt;

  PatientInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    required this.createdAt,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) {
    return PatientInfo(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      gender: json['gender'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get fullName => '$firstName $lastName';
}

class PatientService {
  final _client = SupabaseConfig.client;

  /// Get patients based on user role
  /// Admins: See all patients
  /// Doctors: Only see assigned patients
  Future<List<PatientInfo>> getPatientsByTenant(
    String tenantId, {
    required String userRole,
    String? doctorId,
  }) async {
    try {
      if (userRole == 'admin') {
        // Admins see all patients
        final response = await _client
            .from('patients')
            .select('id, first_name, last_name, email, phone, date_of_birth, gender, created_at')
            .eq('tenant_id', tenantId)
            .order('created_at', ascending: false);

        return (response as List)
            .map((json) => PatientInfo.fromJson(json))
            .toList();
      } else {
        // Doctors only see assigned patients
        if (doctorId == null) return [];
        
        // Get active assignments first
        final assignments = await _client
            .from('patient_assignments')
            .select('patient_id')
            .eq('doctor_id', doctorId)
            .eq('status', 'active');
        
        if (assignments.isEmpty) return [];
        
        final patientIds = (assignments as List)
            .map((a) => a['patient_id'] as String)
            .toList();
        
        final response = await _client
            .from('patients')
            .select('id, first_name, last_name, email, phone, date_of_birth, gender, created_at')
            .eq('tenant_id', tenantId)
            .inFilter('id', patientIds)
            .order('created_at', ascending: false);

        return (response as List)
            .map((json) => PatientInfo.fromJson(json))
            .toList();
      }
    } catch (e) {
      throw Exception('Failed to fetch patients: $e');
    }
  }

  Future<PatientInfo?> getPatientById(String patientId) async {
    try {
      final response = await _client
          .from('patients')
          .select('id, first_name, last_name, email, phone, date_of_birth, gender, created_at')
          .eq('id', patientId)
          .maybeSingle();

      if (response == null) return null;
      return PatientInfo.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch patient: $e');
    }
  }

  Future<PatientInfo?> getPatientByUserId(String userId) async {
    try {
      final response = await _client
          .from('patients')
          .select('id, first_name, last_name, email, phone, date_of_birth, gender, created_at, user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return PatientInfo.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch patient by user ID: $e');
    }
  }

  Future<void> createPatient({
    required String tenantId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    DateTime? dateOfBirth,
    String? gender,
    String? userId,
  }) async {
    try {
      await _client.from('patients').insert({
        'tenant_id': tenantId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'user_id': userId,
      });
    } catch (e) {
      throw Exception('Failed to create patient: $e');
    }
  }

  Future<PatientInfo?> findPatientByPhone(String tenantId, String phone) async {
    try {
      final response = await _client
          .from('patients')
          .select('id, first_name, last_name, email, phone, date_of_birth, gender, created_at, user_id')
          .eq('tenant_id', tenantId)
          .eq('phone', phone)
          .maybeSingle();

      if (response == null) return null;
      return PatientInfo.fromJson(response);
    } catch (e) {
      throw Exception('Failed to find patient by phone: $e');
    }
  }

  Future<void> linkUserToPatient(String patientId, String userId) async {
    try {
      await _client.from('patients').update({
        'user_id': userId,
      }).eq('id', patientId);
    } catch (e) {
      throw Exception('Failed to link user to patient: $e');
    }
  }
}

final patientServiceProvider = Provider<PatientService>((ref) => PatientService());

// Provider for current user's role in current hospital
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final currentHospital = ref.watch(currentHospitalProvider);
  
  final userId = authService.currentUser?.id;
  if (userId == null || currentHospital == null) return null;
  
  final userRole = await authService.getUserRoleForTenant(
    userId: userId,
    tenantId: currentHospital.id,
  );
  
  return userRole?.role.name;
});

// Stream to auto-update when new patients are added
// Filtered by role: admins see all, doctors see only assigned
final patientsListProvider = StreamProvider<List<PatientInfo>>((ref) async* {
  final currentHospital = ref.watch(currentHospitalProvider);
  final userRole = await ref.watch(currentUserRoleProvider.future);
  final doctorProfile = userRole == 'doctor' 
      ? await ref.watch(doctorProfileProvider.future)
      : null;
  
  if (currentHospital == null || userRole == null) {
    yield [];
    return;
  }

  final service = ref.watch(patientServiceProvider);
  
  if (userRole == 'admin') {
    // Admins see all patients
    yield* service
        .getPatientsStream(currentHospital.id)
        .map((rows) => rows.map(PatientInfo.fromJson).toList());
  } else {
    // Doctors see only assigned patients
    if (doctorProfile == null) {
      yield [];
      return;
    }
    
    yield* service
        .getAssignedPatientsStream(currentHospital.id, doctorProfile.id)
        .map((rows) => rows.map(PatientInfo.fromJson).toList());
  }
});

// Provider to get current patient's profile
final currentPatientProfileProvider = FutureProvider<PatientInfo?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null || authState.session == null) return null;

  final userId = authState.session!.user.id;
  final service = ref.watch(patientServiceProvider);
  return await service.getPatientByUserId(userId);
});

extension on PatientService {
  Stream<List<Map<String, dynamic>>> getPatientsStream(String tenantId) {
    return _client
        .from('patients')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
  }
  
  Stream<List<Map<String, dynamic>>> getAssignedPatientsStream(String tenantId, String doctorId) {
    // Stream patients that have active assignments to this doctor
    return _client
        .from('patients')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .asyncMap((patients) async {
          // Get active assignments for this doctor
          final assignments = await _client
              .from('patient_assignments')
              .select('patient_id')
              .eq('doctor_id', doctorId)
              .eq('status', 'active');
          
          final assignedPatientIds = (assignments as List)
              .map((a) => a['patient_id'] as String)
              .toSet();
          
          // Filter patients to only assigned ones
          return patients
              .where((p) => assignedPatientIds.contains(p['id']))
              .toList();
        });
  }
}
