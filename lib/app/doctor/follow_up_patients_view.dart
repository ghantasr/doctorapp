import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/supabase/supabase_config.dart';

// Provider for follow-up patients
final followUpPatientsProvider = StreamProvider.autoDispose((ref) async* {
  final doctor = await ref.watch(doctorProfileProvider.future);
  if (doctor == null) {
    print('DEBUG: No doctor profile found');
    yield <Map<String, dynamic>>[];
    return;
  }

  print('DEBUG: Fetching assignments for doctor: ${doctor.id}');

  final stream = SupabaseConfig.client
      .from('patient_assignments')
      .stream(primaryKey: ['id'])
      .eq('doctor_id', doctor.id);

  await for (final data in stream) {
    // Filter patients with follow-up dates
    final patientsWithFollowUp = <Map<String, dynamic>>[];
    
    print('DEBUG: ========================================');
    print('DEBUG: Total assignments received: ${data.length}');
    
    for (var assignment in data) {
      print('DEBUG: --- Assignment ID: ${assignment['id']} ---');
      print('DEBUG:   Status: ${assignment['status']}');
      print('DEBUG:   Follow-up date: ${assignment['follow_up_date']}');
      print('DEBUG:   Last visit date: ${assignment['last_visit_date']}');
      print('DEBUG:   Patient ID: ${assignment['patient_id']}');
      
      // Only show active assignments
      if (assignment['status'] != 'active') {
        print('DEBUG:   SKIPPED - Not active');
        continue;
      }
      
      if (assignment['follow_up_date'] != null) {
        try {
          final followUpDate = DateTime.parse(assignment['follow_up_date']);
          final lastVisitDate = assignment['last_visit_date'] != null 
              ? DateTime.parse(assignment['last_visit_date']) 
              : null;
          
          print('DEBUG:   Parsed follow-up: $followUpDate');
          print('DEBUG:   Parsed last visit: $lastVisitDate');
          
          // Only show if:
          // 1. Has a follow-up date
          // 2. Either never visited OR last visit was before the current follow-up date
          final shouldShow = lastVisitDate == null || lastVisitDate.isBefore(followUpDate);
          
          print('DEBUG:   Should show: $shouldShow (lastVisit null: ${lastVisitDate == null}, or before followUp: ${lastVisitDate != null && lastVisitDate.isBefore(followUpDate)})');
          
          if (shouldShow) {
            // Fetch patient details
            try {
              final patientData = await SupabaseConfig.client
                  .from('patients')
                  .select()
                  .eq('id', assignment['patient_id'])
                  .single();
              
              print('DEBUG:   ✓ Added patient: ${patientData['first_name']} ${patientData['last_name']}');
              
              patientsWithFollowUp.add({
                ...assignment,
                'patient': patientData,
              });
            } catch (e) {
              print('DEBUG:   ✗ Error fetching patient: $e');
              // Skip if patient not found
              continue;
            }
          }
        } catch (e) {
          print('DEBUG:   ✗ Error parsing dates: $e');
        }
      } else {
        print('DEBUG:   SKIPPED - No follow-up date set');
      }
    }
    
    print('DEBUG: ========================================');
    print('DEBUG: FINAL COUNT - Total follow-up patients to show: ${patientsWithFollowUp.length}');
    
    yield patientsWithFollowUp;
  }
});

class FollowUpPatientsView extends ConsumerWidget {
  const FollowUpPatientsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUpPatientsAsync = ref.watch(followUpPatientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-Up Patients'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: followUpPatientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
        data: (followUpPatients) {
          if (followUpPatients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Follow-Up Patients',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Patients with scheduled follow-ups will appear here',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          // Categorize patients
          final overduePatients = <Map<String, dynamic>>[];
          final todayPatients = <Map<String, dynamic>>[];
          final upcomingPatients = <Map<String, dynamic>>[];
          
          for (var patient in followUpPatients) {
            final followUpDate = DateTime.parse(patient['follow_up_date']).toLocal();
            final followUpDay = DateTime(followUpDate.year, followUpDate.month, followUpDate.day);
            
            if (followUpDay.isBefore(today)) {
              overduePatients.add(patient);
            } else if (followUpDay.isAtSameMomentAs(today)) {
              todayPatients.add(patient);
            } else {
              upcomingPatients.add(patient);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Overdue',
                      overduePatients.length,
                      Icons.warning_amber_rounded,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Today',
                      todayPatients.length,
                      Icons.today_rounded,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Upcoming',
                      upcomingPatients.length,
                      Icons.upcoming_rounded,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              
              // Overdue Section
              if (overduePatients.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Overdue Follow-Ups',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 12),
                ...overduePatients.map((patient) => _buildPatientCard(
                  context,
                  patient,
                  Colors.red,
                  'Overdue',
                )),
              ],
              
              // Today Section
              if (todayPatients.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Follow-Ups Today',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 12),
                ...todayPatients.map((patient) => _buildPatientCard(
                  context,
                  patient,
                  Colors.blue,
                  'Today',
                )),
              ],
              
              // Upcoming Section
              if (upcomingPatients.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Upcoming Follow-Ups',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...upcomingPatients.map((patient) => _buildPatientCard(
                  context,
                  patient,
                  Colors.green,
                  null,
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(
    BuildContext context,
    Map<String, dynamic> assignmentData,
    Color accentColor,
    String? statusLabel,
  ) {
    final patientData = assignmentData['patient'] as Map<String, dynamic>;
    final followUpDate = DateTime.parse(assignmentData['follow_up_date']).toLocal();
    final now = DateTime.now();
    final daysUntil = followUpDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    
    String daysText;
    if (daysUntil < 0) {
      daysText = '${-daysUntil} days overdue';
    } else if (daysUntil == 0) {
      daysText = 'Today';
    } else if (daysUntil == 1) {
      daysText = 'Tomorrow';
    } else {
      daysText = 'In $daysUntil days';
    }
    
    // Show notification indicator if within 2 days
    final showNotificationIndicator = daysUntil >= 0 && daysUntil <= 2;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: accentColor.withOpacity(0.1),
              child: Text(
                patientData['first_name'][0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
            if (showNotificationIndicator)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          '${patientData['first_name']} ${patientData['last_name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(followUpDate),
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(daysText, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (showNotificationIndicator)
              const Row(
                children: [
                  Icon(Icons.notifications_active, size: 12, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Reminder sent',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ),
          ],
        ),
        trailing: statusLabel != null
            ? Chip(
                label: Text(
                  statusLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                backgroundColor: accentColor.withOpacity(0.1),
                side: BorderSide(color: accentColor),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to patient detail (you'll need to create PatientInfo from the data)
          // For now, just show a message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up for ${patientData['first_name']} ${patientData['last_name']}'),
            ),
          );
        },
      ),
    );
  }
}
