import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../doctor/doctor_service.dart';

class PatientAssignment {
  final String id;
  final String patientId;
  final String doctorId;
  final String tenantId;
  final String assignedBy;
  final DateTime assignedAt;
  final String status; // active, completed, returned
  final String? notes;
  final DateTime? followUpDate;
  final DoctorProfile? doctor; // Joined doctor info

  PatientAssignment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.tenantId,
    required this.assignedBy,
    required this.assignedAt,
    required this.status,
    this.notes,
    this.followUpDate,
    this.doctor,
  });

  factory PatientAssignment.fromJson(Map<String, dynamic> json) {
    return PatientAssignment(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      tenantId: json['tenant_id'],
      assignedBy: json['assigned_by'],
      assignedAt: DateTime.parse(json['assigned_at']),
      status: json['status'],
      notes: json['notes'],
      followUpDate: json['follow_up_date'] != null 
          ? DateTime.parse(json['follow_up_date'])
          : null,
      doctor: json['doctors'] != null 
          ? DoctorProfile.fromJson(json['doctors'])
          : null,
    );
  }
}

class PatientAssignmentService {
  final _client = SupabaseConfig.client;

  /// Assign a patient to a doctor
  Future<void> assignPatient({
    required String patientId,
    required String doctorId,
    required String tenantId,
    required String assignedBy,
    String? notes,
  }) async {
    try {
      // Check if there's already an active assignment
      final existing = await _client
          .from('patient_assignments')
          .select('id')
          .eq('patient_id', patientId)
          .eq('doctor_id', doctorId)
          .eq('status', 'active')
          .maybeSingle();

      if (existing != null) {
        throw Exception('Patient is already assigned to this doctor');
      }

      await _client.from('patient_assignments').insert({
        'patient_id': patientId,
        'doctor_id': doctorId,
        'tenant_id': tenantId,
        'assigned_by': assignedBy,
        'status': 'active',
        'notes': notes,
      });
    } catch (e) {
      throw Exception('Failed to assign patient: $e');
    }
  }

  /// Get active assignment for a patient
  Future<PatientAssignment?> getActiveAssignment(String patientId) async {
    try {
      final response = await _client
          .from('patient_assignments')
          .select('''
            id, patient_id, doctor_id, tenant_id, assigned_by, assigned_at, status, notes, follow_up_date,
            doctors:doctor_id (
              id, first_name, last_name, specialty, phone
            )
          ''')
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;
      return PatientAssignment.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get assignment: $e');
    }
  }

  /// Get all assignments for a patient (history)
  Future<List<PatientAssignment>> getPatientAssignments(String patientId) async {
    try {
      final response = await _client
          .from('patient_assignments')
          .select('''
            id, patient_id, doctor_id, tenant_id, assigned_by, assigned_at, status, notes,
            doctors:doctor_id (
              id, first_name, last_name, specialty, phone
            )
          ''')
          .eq('patient_id', patientId)
          .order('assigned_at', ascending: false);

      return (response as List)
          .map((json) => PatientAssignment.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get assignments: $e');
    }
  }

  /// Complete an assignment (doctor finishes treatment)
  Future<void> completeAssignment(String assignmentId) async {
    try {
      await _client
          .from('patient_assignments')
          .update({'status': 'completed'})
          .eq('id', assignmentId);
    } catch (e) {
      throw Exception('Failed to complete assignment: $e');
    }
  }

  /// Return patient to admin for reassignment
  Future<void> returnToAdmin(String assignmentId) async {
    try {
      await _client
          .from('patient_assignments')
          .update({'status': 'returned'})
          .eq('id', assignmentId);
    } catch (e) {
      throw Exception('Failed to return patient: $e');
    }
  }

  /// Update follow-up date for a patient assignment
  Future<void> updateFollowUpDate({
    required String patientId,
    required String doctorId,
    required DateTime? followUpDate,
  }) async {
    try {
      await _client
          .from('patient_assignments')
          .update({
            'follow_up_date': followUpDate?.toIso8601String(),
          })
          .eq('patient_id', patientId)
          .eq('doctor_id', doctorId)
          .eq('status', 'active');
    } catch (e) {
      throw Exception('Failed to update follow-up date: $e');
    }
  }

  /// Mark patient as visited for current follow-up (updates last_visit_date)
  Future<void> markAsVisitedForFollowUp({
    required String patientId,
    required String doctorId,
  }) async {
    try {
      await _client
          .from('patient_assignments')
          .update({
            'last_visit_date': DateTime.now().toIso8601String(),
          })
          .eq('patient_id', patientId)
          .eq('doctor_id', doctorId)
          .eq('status', 'active');
    } catch (e) {
      throw Exception('Failed to mark patient as visited: $e');
    }
  }

  /// Get follow-up date for a patient
  Future<DateTime?> getFollowUpDate({
    required String patientId,
    required String doctorId,
  }) async {
    try {
      final response = await _client
          .from('patient_assignments')
          .select('follow_up_date')
          .eq('patient_id', patientId)
          .eq('doctor_id', doctorId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null || response['follow_up_date'] == null) {
        return null;
      }
      return DateTime.parse(response['follow_up_date']);
    } catch (e) {
      throw Exception('Failed to get follow-up date: $e');
    }
  }

  /// Reassign patient to another doctor (admin only)
  Future<void> reassignPatient({
    required String patientId,
    required String newDoctorId,
    required String tenantId,
    required String assignedBy,
    String? notes,
  }) async {
    try {
      // Mark any existing active assignments as returned
      await _client
          .from('patient_assignments')
          .update({'status': 'returned'})
          .eq('patient_id', patientId)
          .eq('status', 'active');

      // Create new assignment
      await assignPatient(
        patientId: patientId,
        doctorId: newDoctorId,
        tenantId: tenantId,
        assignedBy: assignedBy,
        notes: notes,
      );
    } catch (e) {
      throw Exception('Failed to reassign patient: $e');
    }
  }
}

final patientAssignmentServiceProvider = Provider<PatientAssignmentService>(
  (ref) => PatientAssignmentService(),
);

// Provider to get active assignment for a patient
final patientActiveAssignmentProvider = FutureProvider.family<PatientAssignment?, String>(
  (ref, patientId) async {
    final service = ref.watch(patientAssignmentServiceProvider);
    return await service.getActiveAssignment(patientId);
  },
);
