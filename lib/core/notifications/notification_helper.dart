import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';

/// Helper service to send notifications via Supabase Edge Function
class NotificationHelper {
  /// Send a follow-up reminder notification
  static Future<bool> sendFollowUpReminder({
    required String doctorId,
    required String patientName,
    required String followUpDate,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-notification',
        body: {
          'type': 'follow_up_reminder',
          'data': {
            'doctor_id': doctorId,
            'patient_name': patientName,
            'follow_up_date': followUpDate,
          },
        },
      );

      return response.data['success'] == true;
    } catch (e) {
      print('Error sending follow-up reminder: $e');
      return false;
    }
  }

  /// Send appointment reminder notification
  static Future<bool> sendAppointmentReminder({
    required String userId,
    required String patientName,
    String? doctorName,
    required String appointmentTime,
    bool isDoctor = true,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-notification',
        body: {
          'type': 'appointment_reminder',
          'data': {
            'user_id': userId,
            'patient_name': patientName,
            'doctor_name': doctorName,
            'appointment_time': appointmentTime,
            'is_doctor': isDoctor,
          },
        },
      );

      return response.data['success'] == true;
    } catch (e) {
      print('Error sending appointment reminder: $e');
      return false;
    }
  }

  /// Send new patient assignment notification
  static Future<bool> sendNewAssignmentNotification({
    required String doctorId,
    required String patientName,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-notification',
        body: {
          'type': 'new_assignment',
          'data': {
            'doctor_id': doctorId,
            'patient_name': patientName,
          },
        },
      );

      return response.data['success'] == true;
    } catch (e) {
      print('Error sending new assignment notification: $e');
      return false;
    }
  }

  /// Send prescription ready notification
  static Future<bool> sendPrescriptionReady({
    required String patientId,
    required String prescriptionId,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-notification',
        body: {
          'type': 'prescription_ready',
          'data': {
            'patient_id': patientId,
            'prescription_id': prescriptionId,
          },
        },
      );

      return response.data['success'] == true;
    } catch (e) {
      print('Error sending prescription notification: $e');
      return false;
    }
  }
}

// Example usage in your app:
/*

// When assigning a patient to a doctor:
await NotificationHelper.sendNewAssignmentNotification(
  doctorId: doctorId,
  patientName: patient.name,
);

// When creating a follow-up:
await NotificationHelper.sendFollowUpReminder(
  doctorId: followUp.doctorId,
  patientName: patient.name,
  followUpDate: followUp.date.toString(),
);

// When appointment is in 1 hour:
await NotificationHelper.sendAppointmentReminder(
  userId: doctorId,
  patientName: patient.name,
  appointmentTime: appointment.time,
  isDoctor: true,
);

*/
