import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../tenant/tenant_service.dart';

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
}

final patientServiceProvider = Provider<PatientService>((ref) => PatientService());

// Stream to auto-update when new patients are added
final patientsListProvider = StreamProvider<List<PatientInfo>>((ref) {
  final tenant = ref.watch(selectedTenantProvider);
  if (tenant == null) return const Stream.empty();

  final service = ref.watch(patientServiceProvider);
  return service
      .getPatientsStream(tenant.id)
      .map((rows) => rows.map(PatientInfo.fromJson).toList());
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
