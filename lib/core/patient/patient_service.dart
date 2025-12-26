import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../auth/auth_service.dart';
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

  Future<List<PatientInfo>> getPatientsByTenant(String tenantId) async {
    try {
      final response = await _client
          .from('patients')
          .select('id, first_name, last_name, email, phone, date_of_birth, gender, created_at')
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientInfo.fromJson(json))
          .toList();
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

// Stream to auto-update when new patients are added
final patientsListProvider = StreamProvider<List<PatientInfo>>((ref) {
  final currentHospital = ref.watch(currentHospitalProvider);
  if (currentHospital == null) return const Stream.empty();

  final service = ref.watch(patientServiceProvider);
  return service
      .getPatientsStream(currentHospital.id)
      .map((rows) => rows.map(PatientInfo.fromJson).toList());
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
}
