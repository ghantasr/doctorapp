import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/patient/patient_service.dart';

class MyAppointmentsView extends ConsumerWidget {
  const MyAppointmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(currentPatientProfileProvider);

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (patient) {
        if (patient == null) {
          return const Center(child: Text('Patient profile not found'));
        }

        final appointmentsStream = SupabaseConfig.client
            .from('appointments')
            .stream(primaryKey: ['id'])
            .eq('patient_id', patient.id)
            .order('appointment_date');

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: appointmentsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final appointments = snapshot.data ?? [];

            if (appointments.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Appointments',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your booked appointments will appear here',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // Group appointments by status
            final upcoming = appointments.where(
              (a) => a['status'] == 'scheduled' && 
                     DateTime.parse(a['appointment_date']).isAfter(DateTime.now())
            ).toList();
            
            final past = appointments.where(
              (a) => a['status'] == 'completed' || 
                     DateTime.parse(a['appointment_date']).isBefore(DateTime.now())
            ).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const Text(
                    'Upcoming Appointments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...upcoming.map((appointment) => _buildAppointmentCard(
                    context,
                    appointment,
                    isUpcoming: true,
                  )),
                  const SizedBox(height: 24),
                ],
                if (past.isNotEmpty) ...[
                  const Text(
                    'Past Appointments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...past.map((appointment) => _buildAppointmentCard(
                    context,
                    appointment,
                    isUpcoming: false,
                  )),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    Map<String, dynamic> appointment, {
    required bool isUpcoming,
  }) {
    final dateTime = DateTime.parse(appointment['appointment_date']).toLocal();
    final duration = appointment['duration_minutes'] as int;
    final status = appointment['status'] as String;
    final doctorId = appointment['doctor_id'] as String;

    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseConfig.client
          .from('doctors')
          .select('first_name, last_name, specialization')
          .eq('id', doctorId)
          .maybeSingle(),
      builder: (context, doctorSnapshot) {
        final doctor = doctorSnapshot.data;
        final doctorName = doctor != null
            ? 'Dr. ${doctor['first_name']} ${doctor['last_name']}'
            : 'Doctor';
        final specialization = doctor?['specialization'] as String?;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isUpcoming ? Colors.blue : Colors.grey,
              child: Icon(
                isUpcoming ? Icons.event : Icons.event_available,
                color: Colors.white,
              ),
            ),
            title: Text(
              doctorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (specialization != null)
                  Text(
                    specialization,
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(dateTime)} at ${TimeOfDay.fromDateTime(dateTime).format(context)}',
                ),
                Text('Duration: $duration minutes'),
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: isUpcoming
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : null,
            onTap: isUpcoming
                ? () {
                    // Future: Show appointment details
                  }
                : null,
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
