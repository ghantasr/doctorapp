import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/patient/patient_service.dart';
import '../../core/patient/patient_assignment_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/widgets/hospital_selector.dart';
import 'medical_records_screen.dart';
import 'team_management_view.dart';
import 'create_bill_screen.dart';
import 'create_prescription_screen.dart';

class PatientDetailScreen extends ConsumerWidget {
  final PatientInfo patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRoleAsync = ref.watch(currentUserRoleProvider);
    final assignmentAsync = ref.watch(patientActiveAssignmentProvider(patient.id));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(patient.fullName),
      ),
      body: userRoleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (userRole) {
          final isAdmin = userRole == 'admin';
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID: ${patient.id}'),
                ),
              ),
              
              // Assignment Status Card
              assignmentAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, stack) => const SizedBox.shrink(),
                data: (assignment) {
                  if (assignment == null && !isAdmin) {
                    return const SizedBox.shrink();
                  }
                  
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                assignment != null ? Icons.assignment : Icons.assignment_outlined,
                                color: assignment != null ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Assignment Status',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (assignment != null) ...[
                            Text(
                              'Assigned to: ${assignment.doctor?.fullName ?? 'Unknown'}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (assignment.doctor?.specialty != null)
                              Text('Specialty: ${assignment.doctor!.specialty}'),
                            Text(
                              'Assigned: ${assignment.assignedAt.toIso8601String().split('T').first}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            if (assignment.notes != null && assignment.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('Notes: ${assignment.notes}'),
                              ),
                            
                            // Follow-up Date Section
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.event_repeat, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Follow-Up Date',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        assignment.followUpDate != null
                                            ? '${assignment.followUpDate!.day}/${assignment.followUpDate!.month}/${assignment.followUpDate!.year}'
                                            : 'Not set',
                                        style: TextStyle(
                                          color: assignment.followUpDate != null 
                                              ? Colors.blue 
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isAdmin)
                                  IconButton(
                                    icon: Icon(
                                      assignment.followUpDate != null 
                                          ? Icons.edit_calendar 
                                          : Icons.add_circle_outline,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _showFollowUpDialog(
                                      context,
                                      ref,
                                      assignment.followUpDate,
                                    ),
                                    tooltip: assignment.followUpDate != null 
                                        ? 'Edit follow-up date' 
                                        : 'Set follow-up date',
                                  ),
                              ],
                            ),
                            
                            // Actions for doctors
                            if (!isAdmin) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _returnToAdmin(context, ref, assignment.id),
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Return to Admin'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _completeAssignment(context, ref, assignment.id),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Complete'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ] else if (isAdmin) ...[
                            Text(
                              'Not assigned to any doctor',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAssignDialog(context, ref),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Assign to Doctor'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              Card(
                child: Column(
                  children: [
                    // Only admins can see contact information
                    if (isAdmin) ...[
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(patient.email ?? 'Not provided'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Phone'),
                        subtitle: Text(patient.phone ?? 'Not provided'),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      leading: const Icon(Icons.cake),
                      title: const Text('DOB'),
                      subtitle: Text(patient.dateOfBirth?.toIso8601String().split('T').first ?? 'Not provided'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.people_alt),
                      title: const Text('Gender'),
                      subtitle: Text(patient.gender ?? 'Not provided'),
                    ),
                  ],
                ),
              ),
              Card(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicalRecordsScreen(patient: patient),
                      ),
                    );
                  },
                  child: const ListTile(
                    leading: Icon(Icons.medical_information),
                    title: Text('Medical Records'),
                    subtitle: Text('View and manage visit history'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                ),
              ),
              
              // Billing and Prescription Section
              const SizedBox(height: 16),
              const Text(
                'Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreateBillScreen(patient: patient),
                            ),
                          );
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bill generated successfully')),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 32, color: Colors.blue),
                              SizedBox(height: 8),
                              Text(
                                'Generate Bill',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreatePrescriptionScreen(patient: patient),
                            ),
                          );
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Prescription created successfully')),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.medication, size: 32, color: Colors.green),
                              SizedBox(height: 8),
                              Text(
                                'Create Prescription',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
    final currentHospital = ref.read(currentHospitalProvider);
    if (currentHospital == null) return;

    // Get list of doctors in this hospital
    final doctors = await ref.read(hospitalDoctorsProvider(currentHospital.id).future);
    
    if (!context.mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _AssignDoctorDialog(doctors: doctors),
    );

    if (result != null && context.mounted) {
      final authService = ref.read(authServiceProvider);
      final assignmentService = ref.read(patientAssignmentServiceProvider);
      
      try {
        await assignmentService.assignPatient(
          patientId: patient.id,
          doctorId: result,
          tenantId: currentHospital.id,
          assignedBy: authService.currentUser!.id,
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient assigned successfully')),
          );
          ref.invalidate(patientActiveAssignmentProvider(patient.id));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to assign: $e')),
          );
        }
      }
    }
  }

  Future<void> _returnToAdmin(BuildContext context, WidgetRef ref, String assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return to Admin'),
        content: const Text('Are you sure you want to return this patient to admin for reassignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final service = ref.read(patientAssignmentServiceProvider);
        await service.returnToAdmin(assignmentId);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient returned to admin')),
          );
          ref.invalidate(patientActiveAssignmentProvider(patient.id));
          ref.invalidate(patientsListProvider);
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to return: $e')),
          );
        }
      }
    }
  }

  Future<void> _completeAssignment(BuildContext context, WidgetRef ref, String assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Treatment'),
        content: const Text('Mark this patient as treatment completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final service = ref.read(patientAssignmentServiceProvider);
        await service.completeAssignment(assignmentId);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Treatment marked as completed')),
          );
          ref.invalidate(patientActiveAssignmentProvider(patient.id));
          ref.invalidate(patientsListProvider);
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to complete: $e')),
          );
        }
      }
    }
  }

  Future<void> _showFollowUpDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime? currentFollowUpDate,
  ) async {
    DateTime selectedDate = currentFollowUpDate ?? DateTime.now().add(const Duration(days: 7));

    final result = await showDialog<DateTime?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Follow-Up Date'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select when the patient should return for follow-up:'),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: const Text('Follow-up Date'),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.edit, color: Colors.blue),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Patient will receive a reminder 2 days before this date.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                if (currentFollowUpDate != null)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, DateTime(1970)), // Special value for clear
                    child: const Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selectedDate),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      try {
        final service = ref.read(patientAssignmentServiceProvider);
        final doctorProfile = await ref.read(doctorProfileProvider.future);
        
        if (doctorProfile == null) {
          throw Exception('Doctor profile not found');
        }

        // Check if we should clear the date
        final dateToSet = result.year == 1970 ? null : result;
        
        await service.updateFollowUpDate(
          patientId: patient.id,
          doctorId: doctorProfile.id,
          followUpDate: dateToSet,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                dateToSet == null 
                    ? 'Follow-up date cleared'
                    : 'Follow-up date set for ${dateToSet.day}/${dateToSet.month}/${dateToSet.year}',
              ),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(patientActiveAssignmentProvider(patient.id));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update follow-up date: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _AssignDoctorDialog extends StatefulWidget {
  final List<DoctorProfile> doctors;
  
  const _AssignDoctorDialog({required this.doctors});

  @override
  State<_AssignDoctorDialog> createState() => _AssignDoctorDialogState();
}

class _AssignDoctorDialogState extends State<_AssignDoctorDialog> {
  String? selectedDoctorId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign to Doctor'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.doctors.isEmpty
            ? const Text('No doctors available')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.doctors.length,
                itemBuilder: (context, index) {
                  final doctor = widget.doctors[index];
                  return RadioListTile<String>(
                    value: doctor.id,
                    groupValue: selectedDoctorId,
                    onChanged: (value) {
                      setState(() {
                        selectedDoctorId = value;
                      });
                    },
                    title: Text(doctor.fullName),
                    subtitle: Text(doctor.specialty.isNotEmpty ? doctor.specialty : 'General'),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedDoctorId == null
              ? null
              : () => Navigator.pop(context, selectedDoctorId),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
