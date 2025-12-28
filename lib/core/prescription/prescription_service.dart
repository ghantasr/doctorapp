import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../patient/patient_service.dart';
import '../doctor/doctor_service.dart';
import '../tenant/tenant.dart';

class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions ?? '',
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      duration: json['duration'] as String,
      instructions: json['instructions'] as String? ?? '',
    );
  }
}

class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final String tenantId;
  final String? visitId;
  final String prescriptionNumber;
  final DateTime prescriptionDate;
  final List<Medication> medications;
  final String? instructions;
  final DateTime? validUntil;
  final String status;
  final DateTime createdAt;
  
  // Populated fields
  final PatientInfo? patient;
  final DoctorProfile? doctor;
  final Tenant? tenant;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.tenantId,
    this.visitId,
    required this.prescriptionNumber,
    required this.prescriptionDate,
    required this.medications,
    this.instructions,
    this.validUntil,
    required this.status,
    required this.createdAt,
    this.patient,
    this.doctor,
    this.tenant,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final medsList = (json['medications'] as List?)
        ?.map((med) => Medication.fromJson(med as Map<String, dynamic>))
        .toList() ?? [];

    return Prescription(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      tenantId: json['tenant_id'],
      visitId: json['visit_id'],
      prescriptionNumber: json['prescription_number'],
      prescriptionDate: DateTime.parse(json['prescription_date']),
      medications: medsList,
      instructions: json['instructions'],
      validUntil: json['valid_until'] != null 
          ? DateTime.parse(json['valid_until']) 
          : null,
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  
  String? get patientName {
    if (patient != null) {
      return '${patient!.firstName} ${patient!.lastName}'.trim();
    }
    return null;
  }
}

class MedicationReminder {
  final String id;
  final String patientId;
  final String prescriptionId;
  final String medicationName;
  final String dosage;
  final String frequency;
  final List<String> reminderTimes;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? notes;

  MedicationReminder({
    required this.id,
    required this.patientId,
    required this.prescriptionId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.reminderTimes,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.notes,
  });

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'],
      patientId: json['patient_id'],
      prescriptionId: json['prescription_id'],
      medicationName: json['medication_name'],
      dosage: json['dosage'],
      frequency: json['frequency'],
      reminderTimes: List<String>.from(json['reminder_times']),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      isActive: json['is_active'],
      notes: json['notes'],
    );
  }
}

class OralHygieneReminder {
  final String id;
  final String patientId;
  final String reminderType;
  final List<String> reminderTimes;
  final String message;
  final bool isActive;

  OralHygieneReminder({
    required this.id,
    required this.patientId,
    required this.reminderType,
    required this.reminderTimes,
    required this.message,
    required this.isActive,
  });

  factory OralHygieneReminder.fromJson(Map<String, dynamic> json) {
    return OralHygieneReminder(
      id: json['id'],
      patientId: json['patient_id'],
      reminderType: json['reminder_type'],
      reminderTimes: List<String>.from(json['reminder_times']),
      message: json['message'],
      isActive: json['is_active'],
    );
  }
}

class PrescriptionService {
  final _client = SupabaseConfig.client;

  Future<String> generatePrescriptionNumber(String tenantId) async {
    try {
      final result = await _client.rpc('nextval', params: {'sequence_name': 'prescription_number_seq'});
      final number = result as int;
      return 'RX-${tenantId.substring(0, 4).toUpperCase()}-$number';
    } catch (e) {
      return 'RX-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<Prescription> createPrescription({
    required String patientId,
    required String doctorId,
    required String tenantId,
    String? visitId,
    required List<Medication> medications,
    String? instructions,
    DateTime? validUntil,
  }) async {
    try {
      final prescriptionNumber = await generatePrescriptionNumber(tenantId);
      
      final response = await _client
          .from('prescriptions')
          .insert({
            'patient_id': patientId,
            'doctor_id': doctorId,
            'tenant_id': tenantId,
            'visit_id': visitId,
            'prescription_number': prescriptionNumber,
            'prescription_date': DateTime.now().toIso8601String().split('T')[0],
            'medications': medications.map((med) => med.toJson()).toList(),
            'instructions': instructions,
            'valid_until': validUntil?.toIso8601String().split('T')[0],
            'status': 'active',
          })
          .select()
          .single();

      return Prescription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create prescription: $e');
    }
  }

  Future<void> updatePrescriptionStatus(String prescriptionId, String status) async {
    try {
      await _client.from('prescriptions').update({
        'status': status,
      }).eq('id', prescriptionId);
    } catch (e) {
      throw Exception('Failed to update prescription status: $e');
    }
  }

  Future<List<Prescription>> getPatientPrescriptions(String patientId) async {
    try {
      final response = await _client
          .from('prescriptions')
          .select('*, patients(id, first_name, last_name), doctors(id, first_name, last_name, specialty, license_number), tenants(id, name, address)')
          .eq('patient_id', patientId)
          .order('prescription_date', ascending: false);

      return (response as List).map((json) {
        final prescription = Prescription.fromJson(json);
        final patientData = json['patients'];
        final doctorData = json['doctors'];
        final tenantData = json['tenants'];
        
        return Prescription(
          id: prescription.id,
          patientId: prescription.patientId,
          doctorId: prescription.doctorId,
          tenantId: prescription.tenantId,
          visitId: prescription.visitId,
          prescriptionNumber: prescription.prescriptionNumber,
          prescriptionDate: prescription.prescriptionDate,
          medications: prescription.medications,
          instructions: prescription.instructions,
          validUntil: prescription.validUntil,
          status: prescription.status,
          createdAt: prescription.createdAt,
          patient: patientData != null ? PatientInfo(
            id: patientData['id'],
            firstName: patientData['first_name'] ?? '',
            lastName: patientData['last_name'] ?? '',
            email: '',
            phone: '',
            createdAt: DateTime.now(),
          ) : null,
          doctor: doctorData != null ? DoctorProfile(
            id: doctorData['id'],
            firstName: doctorData['first_name'] ?? '',
            lastName: doctorData['last_name'] ?? '',
            specialty: doctorData['specialty'] ?? '',
            licenseNumber: doctorData['license_number'] ?? '',
            tenantId: prescription.tenantId,
            userId: '',
          ) : null,
          tenant: tenantData != null ? Tenant(
            id: tenantData['id'],
            name: tenantData['name'] ?? '',
            address: tenantData['address'],
          ) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch prescriptions: $e');
    }
  }

  Future<List<Prescription>> getDoctorPrescriptions(String doctorId) async {
    try {
      final response = await _client
          .from('prescriptions')
          .select('*, patients(id, first_name, last_name), doctors(id, first_name, last_name, specialty, license_number), tenants(id, name, address)')
          .eq('doctor_id', doctorId)
          .order('prescription_date', ascending: false);

      return (response as List).map((json) {
        final prescription = Prescription.fromJson(json);
        final patientData = json['patients'];
        final doctorData = json['doctors'];
        final tenantData = json['tenants'];
        
        return Prescription(
          id: prescription.id,
          patientId: prescription.patientId,
          doctorId: prescription.doctorId,
          tenantId: prescription.tenantId,
          visitId: prescription.visitId,
          prescriptionNumber: prescription.prescriptionNumber,
          prescriptionDate: prescription.prescriptionDate,
          medications: prescription.medications,
          instructions: prescription.instructions,
          validUntil: prescription.validUntil,
          status: prescription.status,
          createdAt: prescription.createdAt,
          patient: patientData != null ? PatientInfo(
            id: patientData['id'],
            firstName: patientData['first_name'] ?? '',
            lastName: patientData['last_name'] ?? '',
            email: '',
            phone: '',
            createdAt: DateTime.now(),
          ) : null,
          doctor: doctorData != null ? DoctorProfile(
            id: doctorData['id'],
            firstName: doctorData['first_name'] ?? '',
            lastName: doctorData['last_name'] ?? '',
            specialty: doctorData['specialty'] ?? '',
            licenseNumber: doctorData['license_number'] ?? '',
            tenantId: prescription.tenantId,
            userId: '',
          ) : null,
          tenant: tenantData != null ? Tenant(
            id: tenantData['id'],
            name: tenantData['name'] ?? '',
            address: tenantData['address'],
          ) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch doctor prescriptions: $e');
    }
  }

  Future<MedicationReminder> createMedicationReminder({
    required String patientId,
    required String prescriptionId,
    required String medicationName,
    required String dosage,
    required String frequency,
    required List<String> reminderTimes,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('medication_reminders')
          .insert({
            'patient_id': patientId,
            'prescription_id': prescriptionId,
            'medication_name': medicationName,
            'dosage': dosage,
            'frequency': frequency,
            'reminder_times': reminderTimes,
            'start_date': startDate.toIso8601String().split('T')[0],
            'end_date': endDate?.toIso8601String().split('T')[0],
            'is_active': true,
            'notes': notes,
          })
          .select()
          .single();

      return MedicationReminder.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create medication reminder: $e');
    }
  }

  Future<OralHygieneReminder> createOralHygieneReminder({
    required String patientId,
    required String reminderType,
    required List<String> reminderTimes,
    required String message,
  }) async {
    try {
      final response = await _client
          .from('oral_hygiene_reminders')
          .insert({
            'patient_id': patientId,
            'reminder_type': reminderType,
            'reminder_times': reminderTimes,
            'message': message,
            'is_active': true,
          })
          .select()
          .single();

      return OralHygieneReminder.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create oral hygiene reminder: $e');
    }
  }

  Future<List<MedicationReminder>> getPatientMedicationReminders(String patientId) async {
    try {
      final response = await _client
          .from('medication_reminders')
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => MedicationReminder.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch medication reminders: $e');
    }
  }

  Future<List<OralHygieneReminder>> getPatientOralHygieneReminders(String patientId) async {
    try {
      final response = await _client
          .from('oral_hygiene_reminders')
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true);

      return (response as List)
          .map((json) => OralHygieneReminder.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch oral hygiene reminders: $e');
    }
  }

  Stream<List<Prescription>> getPatientPrescriptionsStream(String patientId) {
    return _client
        .from('prescriptions')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('prescription_date', ascending: false)
        .asyncMap((rows) async {
          final List<Prescription> prescriptions = [];
          
          for (final row in rows) {
            // Fetch related data for each prescription
            final patientData = await _client
                .from('patients')
                .select('id, first_name, last_name')
                .eq('id', row['patient_id'])
                .maybeSingle();
            
            final doctorData = await _client
                .from('doctors')
                .select('id, first_name, last_name, specialty, license_number')
                .eq('id', row['doctor_id'])
                .maybeSingle();
            
            final tenantData = await _client
                .from('tenants')
                .select('id, name, address')
                .eq('id', row['tenant_id'])
                .maybeSingle();
            
            final prescription = Prescription.fromJson(row);
            
            prescriptions.add(Prescription(
              id: prescription.id,
              patientId: prescription.patientId,
              doctorId: prescription.doctorId,
              tenantId: prescription.tenantId,
              visitId: prescription.visitId,
              prescriptionNumber: prescription.prescriptionNumber,
              prescriptionDate: prescription.prescriptionDate,
              medications: prescription.medications,
              instructions: prescription.instructions,
              validUntil: prescription.validUntil,
              status: prescription.status,
              createdAt: prescription.createdAt,
              patient: patientData != null ? PatientInfo(
                id: patientData['id'],
                firstName: patientData['first_name'] ?? '',
                lastName: patientData['last_name'] ?? '',
                email: '',
                phone: '',
                createdAt: DateTime.now(),
              ) : null,
              doctor: doctorData != null ? DoctorProfile(
                id: doctorData['id'],
                firstName: doctorData['first_name'] ?? '',
                lastName: doctorData['last_name'] ?? '',
                specialty: doctorData['specialty'] ?? '',
                licenseNumber: doctorData['license_number'] ?? '',
                tenantId: prescription.tenantId,
                userId: '',
              ) : null,
              tenant: tenantData != null ? Tenant(
                id: tenantData['id'],
                name: tenantData['name'] ?? '',
                address: tenantData['address'],
              ) : null,
            ));
          }
          
          return prescriptions;
        });
  }
}

final prescriptionServiceProvider = Provider<PrescriptionService>((ref) => PrescriptionService());

final patientPrescriptionsProvider = StreamProvider.family<List<Prescription>, String>((ref, patientId) {
  final service = ref.watch(prescriptionServiceProvider);
  return service.getPatientPrescriptionsStream(patientId);
});

final doctorPrescriptionsProvider = FutureProvider.family<List<Prescription>, String>((ref, doctorId) async {
  final service = ref.watch(prescriptionServiceProvider);
  return service.getDoctorPrescriptions(doctorId);
});
