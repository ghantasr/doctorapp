import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/supabase/supabase_config.dart';

class DoctorAppointmentsEnhancedView extends ConsumerStatefulWidget {
  const DoctorAppointmentsEnhancedView({super.key});

  @override
  ConsumerState<DoctorAppointmentsEnhancedView> createState() => _DoctorAppointmentsEnhancedViewState();
}

class _DoctorAppointmentsEnhancedViewState extends ConsumerState<DoctorAppointmentsEnhancedView> {
  final Map<String, String> _patientNamesCache = {};

  Future<String> _getPatientName(String? patientId) async {
    if (patientId == null) return 'Unknown Patient';
    
    // Check cache first
    if (_patientNamesCache.containsKey(patientId)) {
      return _patientNamesCache[patientId]!;
    }

    try {
      final response = await SupabaseConfig.client
          .from('patients')
          .select('first_name, last_name')
          .eq('id', patientId)
          .single();
      
      final name = '${response['first_name']} ${response['last_name']}';
      _patientNamesCache[patientId] = name;
      return name;
    } catch (e) {
      return 'Unknown Patient';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(doctorProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Profile not found'));
        }

        final slotsStream = SupabaseConfig.client
            .from('appointments')
            .stream(primaryKey: ['id'])
            .eq('doctor_id', profile.id)
            .order('appointment_date');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appointments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/createSlots');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Slots'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your appointment schedule',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: slotsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_available,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No slots created yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create time slots for patients to book',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/createSlots');
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Create Your First Slot'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final now = DateTime.now();
                
                // Categorize appointments
                final upcomingSlots = <Map<String, dynamic>>[];
                final missedSlots = <Map<String, dynamic>>[];
                
                for (var row in rows) {
                  final appointmentTime = DateTime.parse(row['appointment_date']).toLocal();
                  final duration = row['duration_minutes'] as int;
                  final endTime = appointmentTime.add(Duration(minutes: duration));
                  final status = row['status'] ?? 'available';
                  final hasPatient = row['patient_id'] != null;
                  
                  // Check if appointment is in the past
                  if (endTime.isBefore(now)) {
                    if (status == 'scheduled' && hasPatient) {
                      // Booked appointment that wasn't completed
                      missedSlots.add(row);
                    }
                    // Skip past available slots (don't show them)
                  } else {
                    // Only show booked appointments or available slots in upcoming
                    // But we'll filter available in the display
                    upcomingSlots.add(row);
                  }
                }

                // Group upcoming slots by date and sort
                final groupedSlots = <String, List<Map<String, dynamic>>>{};
                for (var row in upcomingSlots) {
                  final date = DateTime.parse(row['appointment_date']).toLocal();
                  final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  groupedSlots.putIfAbsent(dateKey, () => []);
                  groupedSlots[dateKey]!.add(row);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics
                    Row(
                      children: [
                        _buildLegendItem(Colors.green, 'Available', upcomingSlots.where((r) => r['status'] == 'available').length),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.blue, 'Booked', upcomingSlots.where((r) => r['status'] == 'scheduled').length),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.orange, 'Missed', missedSlots.length),
                      ],
                    ),
                    
                    // Missed Appointments Section
                    if (missedSlots.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Missed Appointments',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 12),
                      ...missedSlots.map((row) {
                        final appointmentTime = DateTime.parse(row['appointment_date']).toLocal();
                        return FutureBuilder<String>(
                          future: _getPatientName(row['patient_id']),
                          builder: (context, snapshot) {
                            final patientName = snapshot.data ?? 'Loading...';
                            return Card(
                              color: Colors.orange.shade50,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.event_busy, color: Colors.orange),
                                title: Text(
                                  patientName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${_getWeekday(appointmentTime.weekday)}, ${appointmentTime.day} ${_getMonth(appointmentTime.month)} - ${TimeOfDay.fromDateTime(appointmentTime).format(context)}',
                                ),
                                trailing: const Text('Missed', style: TextStyle(color: Colors.orange)),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                    
                    // Upcoming Appointments Section (Booked Only)
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upcoming Appointments',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/createSlots');
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Slots'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Filter to show only booked appointments
                    Builder(builder: (context) {
                      final bookedSlots = upcomingSlots.where((slot) => 
                        slot['status'] == 'scheduled' && slot['patient_id'] != null
                      ).toList();
                      
                      if (bookedSlots.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.event_available_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text(
                                  'No booked appointments',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Patients haven\'t booked any appointments yet',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Group booked appointments by date
                      final groupedBooked = <String, List<Map<String, dynamic>>>{};
                      for (var row in bookedSlots) {
                        final date = DateTime.parse(row['appointment_date']).toLocal();
                        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        groupedBooked.putIfAbsent(dateKey, () => []);
                        groupedBooked[dateKey]!.add(row);
                      }
                      
                      final sortedBookedDates = groupedBooked.keys.toList()
                        ..sort((a, b) => a.compareTo(b));
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedBookedDates.map((dateKey) {
                          final slots = groupedBooked[dateKey]!;
                          final date = DateTime.parse(slots.first['appointment_date']).toLocal();
                          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                          final isTomorrow = date.year == now.year && date.month == now.month && date.day == now.day + 1;
                          
                          String dateLabel = '${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)} ${date.year}';
                          if (isToday) dateLabel = 'Today, $dateLabel';
                          if (isTomorrow) dateLabel = 'Tomorrow, $dateLabel';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isToday ? Colors.blue : Colors.black87,
                                  ),
                                ),
                              ),
                              ...slots.map((row) {
                                final start = DateTime.parse(row['appointment_date']).toLocal();
                                return FutureBuilder<String>(
                                  future: _getPatientName(row['patient_id']),
                                  builder: (context, snapshot) {
                                    final patientName = snapshot.data ?? 'Loading...';
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: Colors.blue.shade50,
                                      child: ListTile(
                                        leading: const Icon(Icons.event, color: Colors.blue),
                                        title: Text(
                                          patientName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          '${TimeOfDay.fromDateTime(start).format(context)} (${row['duration_minutes']}m)',
                                        ),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      ),
                                    );
                                  },
                                );
                              }),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      );
                    }),
                    
                    // Available Slots Section
                    const SizedBox(height: 24),
                    const Text(
                      'Available Slots',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    Builder(builder: (context) {
                      // Filter only available slots
                      final availableSlots = upcomingSlots.where((slot) => 
                        slot['status'] == 'available'
                      ).toList();
                      
                      if (availableSlots.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text(
                                  'No available slots',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create new slots for patients to book',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Group available slots by date
                      final groupedAvailable = <String, List<Map<String, dynamic>>>{};
                      for (var row in availableSlots) {
                        final date = DateTime.parse(row['appointment_date']).toLocal();
                        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        groupedAvailable.putIfAbsent(dateKey, () => []);
                        groupedAvailable[dateKey]!.add(row);
                      }
                      
                      final sortedAvailableDates = groupedAvailable.keys.toList()
                        ..sort((a, b) => a.compareTo(b));
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedAvailableDates.map((dateKey) {
                          final slots = groupedAvailable[dateKey]!;
                          final date = DateTime.parse(slots.first['appointment_date']).toLocal();
                          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                          final isTomorrow = date.year == now.year && date.month == now.month && date.day == now.day + 1;
                          
                          String dateLabel = '${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)} ${date.year}';
                          if (isToday) dateLabel = 'Today, $dateLabel';
                          if (isTomorrow) dateLabel = 'Tomorrow, $dateLabel';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isToday ? Colors.blue : Colors.black87,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: slots.map((row) {
                                  final start = DateTime.parse(row['appointment_date']).toLocal();
                                  
                                  return InkWell(
                                    onLongPress: () => _showDeleteSlotDialog(context, row['id'], start),
                                    child: Chip(
                                      backgroundColor: Colors.green.shade50,
                                      side: const BorderSide(color: Colors.green),
                                      label: Text(
                                        '${TimeOfDay.fromDateTime(start).format(context)} (${row['duration_minutes']}m)',
                                        style: TextStyle(color: Colors.green.shade900),
                                      ),
                                      avatar: const Icon(
                                        Icons.event_available,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      deleteIcon: const Icon(Icons.close, size: 18),
                                      onDeleted: () => _deleteSlot(context, row['id']),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Future<void> _deleteSlot(BuildContext context, String slotId) async {
    try {
      await SupabaseConfig.client
          .from('appointments')
          .delete()
          .eq('id', slotId)
          .eq('status', 'available'); // Extra safety: only delete if still available

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete slot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteSlotDialog(BuildContext context, String slotId, DateTime time) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Slot'),
          content: Text(
            'Are you sure you want to delete the slot at ${TimeOfDay.fromDateTime(time).format(context)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteSlot(context, slotId);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
