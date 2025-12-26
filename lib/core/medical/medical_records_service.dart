import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';

enum ToothStatus {
  problem,
  inProgress,
  completed,
  healthy;

  String get dbValue {
    switch (this) {
      case ToothStatus.problem:
        return 'problem';
      case ToothStatus.inProgress:
        return 'in_progress';
      case ToothStatus.completed:
        return 'completed';
      case ToothStatus.healthy:
        return 'healthy';
    }
  }

  static ToothStatus fromString(String value) {
    switch (value) {
      case 'problem':
        return ToothStatus.problem;
      case 'in_progress':
        return ToothStatus.inProgress;
      case 'completed':
        return ToothStatus.completed;
      case 'healthy':
        return ToothStatus.healthy;
      default:
        return ToothStatus.healthy;
    }
  }
}

class ToothRecord {
  final String id;
  final String visitId;
  final int toothNumber;
  final ToothStatus status;
  final String? notes;

  ToothRecord({
    required this.id,
    required this.visitId,
    required this.toothNumber,
    required this.status,
    this.notes,
  });

  factory ToothRecord.fromJson(Map<String, dynamic> json) {
    return ToothRecord(
      id: json['id'],
      visitId: json['visit_id'],
      toothNumber: json['tooth_number'],
      status: ToothStatus.fromString(json['status']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visit_id': visitId,
      'tooth_number': toothNumber,
      'status': status.dbValue,
      'notes': notes,
    };
  }
}

class MedicalVisit {
  final String id;
  final String patientId;
  final String doctorId;
  final String tenantId;
  final DateTime visitDate;
  final String? chiefComplaint;
  final String? diagnosis;
  final String? treatmentPlan;
  final String? notes;
  final List<ToothRecord> toothRecords;

  MedicalVisit({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.tenantId,
    required this.visitDate,
    this.chiefComplaint,
    this.diagnosis,
    this.treatmentPlan,
    this.notes,
    this.toothRecords = const [],
  });

  factory MedicalVisit.fromJson(Map<String, dynamic> json) {
    return MedicalVisit(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      tenantId: json['tenant_id'],
      visitDate: DateTime.parse(json['visit_date']),
      chiefComplaint: json['chief_complaint'],
      diagnosis: json['diagnosis'],
      treatmentPlan: json['treatment_plan'],
      notes: json['notes'],
      toothRecords: [],
    );
  }
}

class MedicalRecordsService {
  final _client = SupabaseConfig.client;

  Future<List<MedicalVisit>> getPatientVisits(String patientId) async {
    try {
      final response = await _client
          .from('medical_visits')
          .select()
          .eq('patient_id', patientId)
          .order('visit_date', ascending: false);

      return (response as List)
          .map((json) => MedicalVisit.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch medical visits: $e');
    }
  }

  Future<List<ToothRecord>> getVisitToothRecords(String visitId) async {
    try {
      final response = await _client
          .from('tooth_records')
          .select()
          .eq('visit_id', visitId)
          .order('tooth_number');

      return (response as List)
          .map((json) => ToothRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tooth records: $e');
    }
  }

  Future<String> createVisit({
    required String patientId,
    required String doctorId,
    required String tenantId,
    String? chiefComplaint,
    String? diagnosis,
    String? treatmentPlan,
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('medical_visits')
          .insert({
            'patient_id': patientId,
            'doctor_id': doctorId,
            'tenant_id': tenantId,
            'chief_complaint': chiefComplaint,
            'diagnosis': diagnosis,
            'treatment_plan': treatmentPlan,
            'notes': notes,
          })
          .select()
          .single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create visit: $e');
    }
  }

  Future<void> saveToothRecords(
    String visitId,
    Map<int, ToothStatus> toothStatuses,
    Map<int, String> toothNotes,
  ) async {
    try {
      // Delete existing tooth records for this visit
      await _client.from('tooth_records').delete().eq('visit_id', visitId);

      // Insert new tooth records
      final records = toothStatuses.entries.map((entry) {
        return {
          'visit_id': visitId,
          'tooth_number': entry.key,
          'status': entry.value.dbValue,
          'notes': toothNotes[entry.key],
        };
      }).toList();

      if (records.isNotEmpty) {
        await _client.from('tooth_records').insert(records);
      }
    } catch (e) {
      throw Exception('Failed to save tooth records: $e');
    }
  }

  Future<void> updateVisit({
    required String visitId,
    String? chiefComplaint,
    String? diagnosis,
    String? treatmentPlan,
    String? notes,
  }) async {
    try {
      await _client.from('medical_visits').update({
        'chief_complaint': chiefComplaint,
        'diagnosis': diagnosis,
        'treatment_plan': treatmentPlan,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', visitId);
    } catch (e) {
      throw Exception('Failed to update visit: $e');
    }
  }
}

final medicalRecordsServiceProvider = Provider<MedicalRecordsService>(
  (ref) => MedicalRecordsService(),
);

final patientVisitsProvider = FutureProvider.family<List<MedicalVisit>, String>(
  (ref, patientId) async {
    final service = ref.watch(medicalRecordsServiceProvider);
    return await service.getPatientVisits(patientId);
  },
);
