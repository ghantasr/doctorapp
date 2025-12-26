import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';
import '../../shared/widgets/hospital_selector.dart';

class DashboardStats {
  final int totalPatients;
  final int totalAppointments;
  final int appointmentsToday;
  final List<AppointmentItem> upcomingAppointments;

  DashboardStats({
    required this.totalPatients,
    required this.totalAppointments,
    required this.appointmentsToday,
    required this.upcomingAppointments,
  });
}

class AppointmentItem {
  final String id;
  final String patientName;
  final String appointmentTime;
  final String type;

  AppointmentItem({
    required this.id,
    required this.patientName,
    required this.appointmentTime,
    required this.type,
  });

  factory AppointmentItem.fromJson(Map<String, dynamic> json) {
    return AppointmentItem(
      id: json['id'] as String,
      patientName: json['patient_name'] as String? ?? 'Unknown',
      appointmentTime: json['appointment_date'] as String? ?? '',
      type: json['status'] as String? ?? 'Consultation',
    );
  }
}

class DashboardService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<DashboardStats> getDashboardStats(String tenantId) async {
    try {
      // Fetch total patients
      final patientsResponse = await _client
          .from('patients')
          .select('id')
          .eq('tenant_id', tenantId);

      final totalPatients = patientsResponse.length;

      // Fetch total appointments
      final appointmentsResponse = await _client
          .from('appointments')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('appointment_date', ascending: false);

      final totalAppointments = appointmentsResponse.length;

      // Count today's appointments
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final appointmentsToday = appointmentsResponse
          .where((apt) {
            try {
              final aptTime = DateTime.parse(apt['appointment_date'] as String);
              return aptTime.isAfter(todayStart) && aptTime.isBefore(todayEnd);
            } catch (e) {
              return false;
            }
          })
          .length;

      // Get upcoming appointments (next 5)
      final upcomingAppointments = appointmentsResponse
          .take(5)
          .map((apt) => AppointmentItem.fromJson(apt))
          .toList();

      return DashboardStats(
        totalPatients: totalPatients,
        totalAppointments: totalAppointments,
        appointmentsToday: appointmentsToday,
        upcomingAppointments: upcomingAppointments,
      );
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  Future<List<AppointmentItem>> getUpcomingAppointments(String tenantId) async {
    try {
      final response = await _client
          .from('appointments')
          .select('*')
          .eq('tenant_id', tenantId)
          .gte('appointment_date', DateTime.now().toIso8601String())
          .order('appointment_date', ascending: true)
          .limit(10);

      return (response as List)
          .map((apt) => AppointmentItem.fromJson(apt))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch appointments: $e');
    }
  }

  Future<int> getTotalPatients(String tenantId) async {
    try {
      final response = await _client
          .from('patients')
          .select('id')
          .eq('tenant_id', tenantId);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getTodaysAppointments(String tenantId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final response = await _client
          .from('appointments')
          .select('id')
          .eq('tenant_id', tenantId)
          .gte('appointment_time', todayStart)
          .lte('appointment_time', todayEnd);

      return response.length;
    } catch (e) {
      return 0;
    }
  }
}

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final dashboardService = ref.watch(dashboardServiceProvider);
  final currentHospital = ref.watch(currentHospitalProvider);

  if (currentHospital == null) {
    throw Exception('No hospital selected');
  }

  return dashboardService.getDashboardStats(currentHospital.id);
});

final upcomingAppointmentsProvider = FutureProvider<List<AppointmentItem>>((ref) async {
  final dashboardService = ref.watch(dashboardServiceProvider);
  final currentHospital = ref.watch(currentHospitalProvider);

  if (currentHospital == null) {
    return [];
  }

  return dashboardService.getUpcomingAppointments(currentHospital.id);
});
