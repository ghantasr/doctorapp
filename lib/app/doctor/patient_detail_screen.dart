import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/patient/patient_service.dart';
import '../../core/patient/patient_assignment_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/widgets/hospital_selector.dart';
import 'medical_records_screen.dart';
import 'team_management_view.dart';

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
