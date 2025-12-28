import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';

class NotificationLog {
  final String id;
  final String userId;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime sentAt;
  final String status;

  NotificationLog({
    required this.id,
    required this.userId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.data,
    required this.sentAt,
    required this.status,
  });

  factory NotificationLog.fromJson(Map<String, dynamic> json) {
    return NotificationLog(
      id: json['id'],
      userId: json['user_id'],
      notificationType: json['notification_type'],
      title: json['title'],
      body: json['body'],
      data: json['data'] ?? {},
      sentAt: DateTime.parse(json['sent_at']),
      status: json['status'] ?? 'sent',
    );
  }
}

class NotificationService {
  final _client = SupabaseConfig.client;

  /// Log a sent notification
  Future<void> logNotification({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.from('notification_logs').insert({
        'user_id': userId,
        'notification_type': notificationType,
        'title': title,
        'body': body,
        'data': data ?? {},
        'status': 'sent',
      });
    } catch (e) {
      print('Error logging notification: $e');
    }
  }

  /// Get notification history for current user
  Future<List<NotificationLog>> getNotificationHistory({int limit = 50}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('notification_logs')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => NotificationLog.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching notification history: $e');
      return [];
    }
  }

  /// Send follow-up reminder notification
  Future<void> sendFollowUpReminder({
    required String doctorId,
    required String patientName,
    required DateTime followUpDate,
  }) async {
    try {
      // Get doctor's FCM token
      final tokenData = await _client
          .from('user_fcm_tokens')
          .select('fcm_token')
          .eq('user_id', doctorId)
          .maybeSingle();

      if (tokenData == null || tokenData['fcm_token'] == null) {
        print('No FCM token found for doctor: $doctorId');
        return;
      }

      // In production, you'd call your backend/Edge Function to send the actual push notification
      // For now, we'll just log it
      await logNotification(
        userId: doctorId,
        notificationType: 'follow_up_reminder',
        title: 'Follow-Up Reminder',
        body: '$patientName has a follow-up scheduled for today',
        data: {
          'patient_name': patientName,
          'follow_up_date': followUpDate.toIso8601String(),
        },
      );

      print('Follow-up reminder notification logged for doctor: $doctorId');
    } catch (e) {
      print('Error sending follow-up reminder: $e');
    }
  }

  /// Send appointment reminder notification
  Future<void> sendAppointmentReminder({
    required String userId,
    required String patientName,
    required DateTime appointmentTime,
  }) async {
    try {
      final tokenData = await _client
          .from('user_fcm_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .maybeSingle();

      if (tokenData == null || tokenData['fcm_token'] == null) {
        print('No FCM token found for user: $userId');
        return;
      }

      await logNotification(
        userId: userId,
        notificationType: 'appointment_reminder',
        title: 'Upcoming Appointment',
        body: 'Appointment with $patientName at ${_formatTime(appointmentTime)}',
        data: {
          'patient_name': patientName,
          'appointment_time': appointmentTime.toIso8601String(),
        },
      );

      print('Appointment reminder notification logged for user: $userId');
    } catch (e) {
      print('Error sending appointment reminder: $e');
    }
  }

  /// Send new patient assignment notification
  Future<void> sendNewAssignmentNotification({
    required String doctorId,
    required String patientName,
    required String patientId,
  }) async {
    try {
      final tokenData = await _client
          .from('user_fcm_tokens')
          .select('fcm_token')
          .eq('user_id', doctorId)
          .maybeSingle();

      if (tokenData == null || tokenData['fcm_token'] == null) {
        print('No FCM token found for doctor: $doctorId');
        return;
      }

      await logNotification(
        userId: doctorId,
        notificationType: 'new_assignment',
        title: 'New Patient Assignment',
        body: '$patientName has been assigned to you',
        data: {
          'patient_name': patientName,
          'patient_id': patientId,
        },
      );

      print('New assignment notification logged for doctor: $doctorId');
    } catch (e) {
      print('Error sending new assignment notification: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Notification history provider
final notificationHistoryProvider = FutureProvider<List<NotificationLog>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotificationHistory();
});
