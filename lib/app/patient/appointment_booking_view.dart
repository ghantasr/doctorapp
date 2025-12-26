import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/tenant/tenant_service.dart';
import '../../core/patient/patient_service.dart';

class AppointmentBookingView extends ConsumerStatefulWidget {
  const AppointmentBookingView({super.key});

  @override
  ConsumerState<AppointmentBookingView> createState() => _AppointmentBookingViewState();
}

class _AppointmentBookingViewState extends ConsumerState<AppointmentBookingView> {
  DateTime? _selectedDate;
  bool _isBooking = false;

  Future<void> _bookAppointment(String appointmentId, String doctorName) async {
    final patient = await ref.read(currentPatientProfileProvider.future);
    
    if (patient == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient profile not found')),
        );
      }
      return;
    }

    setState(() => _isBooking = true);

    try {
      // Check if patient already has an appointment at this time
      final appointment = await SupabaseConfig.client
          .from('appointments')
          .select('appointment_date, duration_minutes')
          .eq('id', appointmentId)
          .single();

      final appointmentTime = DateTime.parse(appointment['appointment_date']);
      final duration = appointment['duration_minutes'] as int;
      final endTime = appointmentTime.add(Duration(minutes: duration));

      // Check for overlapping appointments
      final overlapping = await SupabaseConfig.client
          .from('appointments')
          .select('id')
          .eq('patient_id', patient.id)
          .gte('appointment_date', appointmentTime.toIso8601String())
          .lt('appointment_date', endTime.toIso8601String())
          .maybeSingle();

      if (overlapping != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an appointment at this time'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Book the appointment
      await SupabaseConfig.client.from('appointments').update({
        'patient_id': patient.id,
        'status': 'scheduled',
      }).eq('id', appointmentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment booked with Dr. $doctorName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(selectedTenantProvider);

    if (tenant == null) {
      return const Center(child: Text('No clinic selected'));
    }

    final now = DateTime.now();
    final startDate = _selectedDate ?? now;
    final endDate = DateTime(startDate.year, startDate.month, startDate.day, 23, 59, 59);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Book an Appointment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: SupabaseConfig.client
                .from('appointments')
                .select()
                .eq('tenant_id', tenant.id)
                .eq('status', 'available')
                .gte('appointment_date', startDate.toIso8601String())
                .lt('appointment_date', endDate.toIso8601String())
                .order('appointment_date'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final slots = snapshot.data ?? [];

              if (slots.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No available slots',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedDate == null
                            ? 'Select a date to view available slots'
                            : 'No slots available for this date',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Group slots by doctor
              final groupedSlots = <String, List<Map<String, dynamic>>>{};
              for (var slot in slots) {
                final doctorId = slot['doctor_id'] as String;
                groupedSlots.putIfAbsent(doctorId, () => []);
                groupedSlots[doctorId]!.add(slot);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groupedSlots.length,
                itemBuilder: (context, index) {
                  final doctorId = groupedSlots.keys.elementAt(index);
                  final doctorSlots = groupedSlots[doctorId]!;

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
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doctorName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (specialization != null)
                                          Text(
                                            specialization,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Available Slots:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: doctorSlots.map((slot) {
                                  final time = DateTime.parse(slot['appointment_date']).toLocal();
                                  final duration = slot['duration_minutes'] as int;
                                  final timeStr = TimeOfDay.fromDateTime(time).format(context);

                                  return ActionChip(
                                    avatar: const Icon(Icons.access_time, size: 18),
                                    label: Text('$timeStr ($duration min)'),
                                    onPressed: _isBooking
                                        ? null
                                        : () => _bookAppointment(slot['id'], doctorName),
                                    backgroundColor: Colors.green.shade50,
                                    side: BorderSide(color: Colors.green.shade200),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
