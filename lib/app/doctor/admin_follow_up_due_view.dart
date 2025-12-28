import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase/supabase_config.dart';

// Provider for admin follow-up patients due soon (within 2 days)
final adminFollowUpDueSoonProvider = StreamProvider.autoDispose((ref) async* {
  final stream = SupabaseConfig.client
      .from('admin_follow_up_due_soon')
      .stream(primaryKey: ['patient_id']);

  await for (final data in stream) {
    print('DEBUG: Admin Follow-up Due Soon - Total: ${data.length}');
    yield data;
  }
});

class AdminFollowUpDueView extends ConsumerWidget {
  const AdminFollowUpDueView({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot make phone calls on this device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUpPatientsAsync = ref.watch(adminFollowUpDueSoonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-Ups Due Soon'),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(adminFollowUpDueSoonProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (patients) {
          if (patients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Follow-Ups Due Soon',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Patients with follow-ups due within 2 days will appear here',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Sort by follow_up_date
          final sortedPatients = List<Map<String, dynamic>>.from(patients);
          sortedPatients.sort((a, b) {
            final dateA = DateTime.parse(a['follow_up_date']);
            final dateB = DateTime.parse(b['follow_up_date']);
            return dateA.compareTo(dateB);
          });

          return Column(
            children: [
              // Summary Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.notifications_active, size: 48, color: Colors.blue.shade700),
                    const SizedBox(height: 8),
                    Text(
                      '${patients.length}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patients.length == 1
                          ? 'Patient needs follow-up reminder'
                          : 'Patients need follow-up reminders',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Patient List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedPatients.length,
                  itemBuilder: (context, index) {
                    final patient = sortedPatients[index];
                    return _buildPatientCard(context, patient);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Map<String, dynamic> patient) {
    final followUpDate = DateTime.parse(patient['follow_up_date']).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final followUpDay = DateTime(followUpDate.year, followUpDate.month, followUpDate.day);
    final daysUntil = followUpDay.difference(today).inDays;
    
    String urgencyLabel;
    Color urgencyColor;
    
    if (daysUntil < 0) {
      urgencyLabel = 'OVERDUE';
      urgencyColor = Colors.red;
    } else if (daysUntil == 0) {
      urgencyLabel = 'TODAY';
      urgencyColor = Colors.orange;
    } else if (daysUntil == 1) {
      urgencyLabel = 'TOMORROW';
      urgencyColor = Colors.amber;
    } else {
      urgencyLabel = 'IN $daysUntil DAYS';
      urgencyColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Name and Urgency Badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['patient_name'] ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Doctor: ${patient['doctor_name'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    urgencyLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Follow-up Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Follow-up: ${DateFormat('EEEE, MMM dd, yyyy').format(followUpDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            if (patient['patient_phone'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient['patient_phone'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            if (patient['patient_email'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient['patient_email'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            
            // Action Buttons
            if (patient['patient_phone'] != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(context, patient['patient_phone']),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call Patient'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Show reminder sent confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Reminder will be automatically sent 2 days before follow-up',
                            ),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications, size: 18),
                      label: const Text('Auto Reminder'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
