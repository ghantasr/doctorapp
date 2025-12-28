import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/prescription/prescription_service.dart';
import '../../core/patient/patient_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../shared/widgets/hospital_selector.dart';

class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  final PatientInfo patient;
  final String? visitId;

  const CreatePrescriptionScreen({
    super.key,
    required this.patient,
    this.visitId,
  });

  @override
  ConsumerState<CreatePrescriptionScreen> createState() => _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends ConsumerState<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<Medication> _medications = [];
  final _instructionsController = TextEditingController();
  DateTime? _validUntil;
  bool _isLoading = false;
  bool _createReminders = true;

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _addMedication() {
    showDialog(
      context: context,
      builder: (context) => _AddMedicationDialog(
        onAdd: (medication) {
          setState(() {
            _medications.add(medication);
          });
        },
      ),
    );
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
  }

  Future<void> _generatePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medication')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doctorProfile = await ref.read(doctorProfileProvider.future);
      final tenant = ref.read(currentHospitalProvider);

      if (doctorProfile == null || tenant == null) {
        throw Exception('Doctor or hospital not found');
      }

      final prescriptionService = ref.read(prescriptionServiceProvider);
      final prescription = await prescriptionService.createPrescription(
        patientId: widget.patient.id,
        doctorId: doctorProfile.id,
        tenantId: tenant.id,
        visitId: widget.visitId,
        medications: _medications,
        instructions: _instructionsController.text.trim().isEmpty 
            ? null 
            : _instructionsController.text.trim(),
        validUntil: _validUntil,
      );

      // Create medication reminders if enabled
      if (_createReminders) {
        for (var medication in _medications) {
          await prescriptionService.createMedicationReminder(
            patientId: widget.patient.id,
            prescriptionId: prescription.id,
            medicationName: medication.name,
            dosage: medication.dosage,
            frequency: medication.frequency,
            reminderTimes: _parseReminderTimes(medication.frequency),
            startDate: DateTime.now(),
            endDate: _calculateEndDate(medication.duration),
            notes: medication.instructions,
          );
        }
        
        // Create oral hygiene reminder for mouthwash if present
        final hasMouthwash = _medications.any((m) => 
          m.name.toLowerCase().contains('mouthwash') ||
          m.name.toLowerCase().contains('rinse')
        );
        
        if (hasMouthwash) {
          await prescriptionService.createOralHygieneReminder(
            patientId: widget.patient.id,
            reminderType: 'mouthwash',
            reminderTimes: ['08:00', '20:00'],
            message: 'Time for your mouthwash rinse! Maintain your oral hygiene.',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_createReminders 
                ? 'Prescription generated and reminders set!' 
                : 'Prescription generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(prescription);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate prescription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _parseReminderTimes(String frequency) {
    // Parse frequency to generate reminder times
    if (frequency.toLowerCase().contains('3 times') || frequency.toLowerCase().contains('thrice')) {
      return ['08:00', '14:00', '20:00'];
    } else if (frequency.toLowerCase().contains('2 times') || frequency.toLowerCase().contains('twice')) {
      return ['08:00', '20:00'];
    } else if (frequency.toLowerCase().contains('4 times')) {
      return ['08:00', '12:00', '16:00', '20:00'];
    } else {
      return ['08:00'];
    }
  }

  DateTime? _calculateEndDate(String duration) {
    final days = int.tryParse(duration.split(' ').first);
    if (days != null) {
      return DateTime.now().add(Duration(days: days));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Prescription'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Patient Information',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text('Name: ${widget.patient.fullName}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Medications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addMedication,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Medication'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_medications.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.medication, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('No medications added yet', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_medications.length, (index) {
                      final med = _medications[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.medication)),
                          title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dosage: ${med.dosage}'),
                              Text('Frequency: ${med.frequency}'),
                              Text('Duration: ${med.duration}'),
                              if (med.instructions != null && med.instructions!.isNotEmpty)
                                Text('Instructions: ${med.instructions}', style: TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeMedication(index),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Valid Until', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _validUntil = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _validUntil != null 
                                    ? '${_validUntil!.day}/${_validUntil!.month}/${_validUntil!.year}'
                                    : 'Select date',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instructionsController,
                    decoration: const InputDecoration(
                      labelText: 'General Instructions (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Additional instructions for the patient',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _createReminders,
                    onChanged: (value) => setState(() => _createReminders = value ?? true),
                    title: const Text('Create medication reminders'),
                    subtitle: const Text('Send notifications to patient for medications and oral hygiene'),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _generatePrescription,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Generate Prescription'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMedicationDialog extends StatefulWidget {
  final Function(Medication) onAdd;

  const _AddMedicationDialog({required this.onAdd});

  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Medication'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  hintText: 'e.g., Amoxicillin',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage *',
                  hintText: 'e.g., 500mg',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Frequency *',
                  hintText: 'e.g., 3 times daily',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration *',
                  hintText: 'e.g., 7 days',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'e.g., Take with food',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final medication = Medication(
                name: _nameController.text.trim(),
                dosage: _dosageController.text.trim(),
                frequency: _frequencyController.text.trim(),
                duration: _durationController.text.trim(),
                instructions: _instructionsController.text.trim(),
              );
              widget.onAdd(medication);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
