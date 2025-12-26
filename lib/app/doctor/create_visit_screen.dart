import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/medical/medical_records_service.dart';
import '../../core/patient/patient_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/tenant/tenant_service.dart';
import '../../shared/widgets/tooth_chart_widget.dart';

class CreateVisitScreen extends ConsumerStatefulWidget {
  final PatientInfo patient;

  const CreateVisitScreen({super.key, required this.patient});

  @override
  ConsumerState<CreateVisitScreen> createState() => _CreateVisitScreenState();
}

class _CreateVisitScreenState extends ConsumerState<CreateVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chiefComplaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentPlanController = TextEditingController();
  final _notesController = TextEditingController();
  
  final Map<int, ToothStatus> _selectedTeeth = {};
  final Map<int, TextEditingController> _toothNoteControllers = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _treatmentPlanController.dispose();
    _notesController.dispose();
    for (var controller in _toothNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onToothTap(int toothNumber, ToothStatus status) {
    setState(() {
      if (_selectedTeeth.containsKey(toothNumber) && _selectedTeeth[toothNumber] == status) {
        // Remove if tapping same status
        _selectedTeeth.remove(toothNumber);
        _toothNoteControllers[toothNumber]?.dispose();
        _toothNoteControllers.remove(toothNumber);
      } else {
        // Add or update
        _selectedTeeth[toothNumber] = status;
        if (!_toothNoteControllers.containsKey(toothNumber)) {
          _toothNoteControllers[toothNumber] = TextEditingController();
        }
      }
    });
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;

    final doctorProfile = await ref.read(doctorProfileProvider.future);
    final tenant = ref.read(selectedTenantProvider);

    if (doctorProfile == null || tenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor profile or tenant not found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final medicalService = ref.read(medicalRecordsServiceProvider);

      // Create the visit
      final visitId = await medicalService.createVisit(
        patientId: widget.patient.id,
        doctorId: doctorProfile.id,
        tenantId: tenant.id,
        chiefComplaint: _chiefComplaintController.text.trim().isEmpty
            ? null
            : _chiefComplaintController.text.trim(),
        diagnosis: _diagnosisController.text.trim().isEmpty
            ? null
            : _diagnosisController.text.trim(),
        treatmentPlan: _treatmentPlanController.text.trim().isEmpty
            ? null
            : _treatmentPlanController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Save tooth records
      final toothNotes = <int, String>{};
      for (var entry in _toothNoteControllers.entries) {
        final note = entry.value.text.trim();
        if (note.isNotEmpty) {
          toothNotes[entry.key] = note;
        }
      }

      await medicalService.saveToothRecords(visitId, _selectedTeeth, toothNotes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit record saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save visit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTeeth = _selectedTeeth.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Medical Visit'),
      ),
      body: Form(
        key: _formKey,
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Name: ${widget.patient.fullName}'),
                    if (widget.patient.dateOfBirth != null)
                      Text('DOB: ${widget.patient.dateOfBirth!.day}/${widget.patient.dateOfBirth!.month}/${widget.patient.dateOfBirth!.year}'),
                    if (widget.patient.phone != null)
                      Text('Phone: ${widget.patient.phone}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _chiefComplaintController,
              decoration: const InputDecoration(
                labelText: 'Chief Complaint',
                hintText: 'What is the main concern?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter chief complaint';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                hintText: 'Clinical diagnosis',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_information),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _treatmentPlanController,
              decoration: const InputDecoration(
                labelText: 'Treatment Plan',
                hintText: 'Planned treatment',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.healing),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'General Notes',
                hintText: 'Additional observations',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            ToothChartWidget(
              selectedTeeth: _selectedTeeth,
              onToothTap: _onToothTap,
              isEditable: true,
            ),
            if (sortedTeeth.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Tooth-Specific Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...sortedTeeth.map((toothNumber) {
                final status = _selectedTeeth[toothNumber]!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _getStatusBorderColor(status)),
                              ),
                              child: Text(
                                'Tooth #$toothNumber',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(_getStatusLabel(status)),
                              backgroundColor: _getStatusColor(status),
                              side: BorderSide(color: _getStatusBorderColor(status)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _toothNoteControllers[toothNumber],
                          decoration: const InputDecoration(
                            labelText: 'Notes for this tooth',
                            hintText: 'Treatment details, observations...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveVisit,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Visit Record'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ToothStatus status) {
    switch (status) {
      case ToothStatus.problem:
        return Colors.red.shade100;
      case ToothStatus.inProgress:
        return Colors.orange.shade100;
      case ToothStatus.completed:
        return Colors.green.shade100;
      case ToothStatus.healthy:
        return Colors.blue.shade100;
    }
  }

  Color _getStatusBorderColor(ToothStatus status) {
    switch (status) {
      case ToothStatus.problem:
        return Colors.red;
      case ToothStatus.inProgress:
        return Colors.orange;
      case ToothStatus.completed:
        return Colors.green;
      case ToothStatus.healthy:
        return Colors.blue;
    }
  }

  String _getStatusLabel(ToothStatus status) {
    switch (status) {
      case ToothStatus.problem:
        return 'Problem';
      case ToothStatus.inProgress:
        return 'In Progress';
      case ToothStatus.completed:
        return 'Completed';
      case ToothStatus.healthy:
        return 'Healthy';
    }
  }
}
