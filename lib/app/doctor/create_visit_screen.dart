import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/medical/medical_records_service.dart';
import '../../core/patient/patient_service.dart';
import '../../core/patient/patient_assignment_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/tenant/tenant_service.dart';
import '../../core/supabase/supabase_config.dart';
import '../../shared/widgets/hospital_selector.dart';
import '../../shared/widgets/tooth_chart_widget.dart';
import 'dart:io';

class CreateVisitScreen extends ConsumerStatefulWidget {
  final PatientInfo patient;
  final MedicalVisit? existingVisit; // For edit mode

  const CreateVisitScreen({
    super.key,
    required this.patient,
    this.existingVisit,
  });

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
  DateTime? _followUpDate;
  bool _markAsVisited = false;
  String? _xrayFileName;
  String? _xrayFilePath;
  String? _xrayUrl;
  
  @override
  void initState() {
    super.initState();
    if (widget.existingVisit != null) {
      // Populate fields with existing data
      _chiefComplaintController.text = widget.existingVisit!.chiefComplaint ?? '';
      _diagnosisController.text = widget.existingVisit!.diagnosis ?? '';
      _treatmentPlanController.text = widget.existingVisit!.treatmentPlan ?? '';
      _notesController.text = widget.existingVisit!.notes ?? '';
      _xrayUrl = widget.existingVisit!.xrayUrl;
      if (_xrayUrl != null) {
        _xrayFileName = _xrayUrl!.split('/').last;
      }
      // Load tooth records
      _loadToothRecords();
    }
  }
  
  Future<void> _loadToothRecords() async {
    if (widget.existingVisit == null) return;
    
    try {
      final medicalService = ref.read(medicalRecordsServiceProvider);
      final toothRecords = await medicalService.getVisitToothRecords(widget.existingVisit!.id);
      
      setState(() {
        for (var record in toothRecords) {
          _selectedTeeth[record.toothNumber] = record.status;
          if (record.notes != null && record.notes!.isNotEmpty) {
            _toothNoteControllers[record.toothNumber] = TextEditingController(text: record.notes);
          }
        }
      });
    } catch (e) {
      // Handle error silently or show message
    }
  }

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

  Future<void> _pickXrayFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _xrayFilePath = result.files.single.path;
          _xrayFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<String?> _uploadXray() async {
    if (_xrayFilePath == null) return null;

    try {
      final file = File(_xrayFilePath!);
      final bytes = await file.readAsBytes();
      final fileExt = _xrayFileName!.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'xrays/${widget.patient.id}/$fileName';

      await SupabaseConfig.client.storage
          .from('medical-records')
          .uploadBinary(filePath, bytes);

      final url = SupabaseConfig.client.storage
          .from('medical-records')
          .getPublicUrl(filePath);

      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload X-ray: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _openXray(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open file';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open X-ray: $e')),
        );
      }
    }
  }

  Future<void> _saveVisit({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final medicalService = ref.read(medicalRecordsServiceProvider);
      final status = submit ? 'submitted' : 'draft';
      final doctorProfile = await ref.read(doctorProfileProvider.future);
      final tenant = ref.read(selectedTenantProvider);
      
      if (doctorProfile == null || tenant == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor profile or tenant not found')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      // Upload X-ray if a new file was selected
      String? xrayUrlToSave = _xrayUrl; // Keep existing URL if no new file
      if (_xrayFilePath != null) {
        final uploadedUrl = await _uploadXray();
        if (uploadedUrl != null) {
          xrayUrlToSave = uploadedUrl;
        }
      }
      
      String visitId;
      
      if (widget.existingVisit != null) {
        // Update existing visit
        visitId = widget.existingVisit!.id;
        await medicalService.updateVisit(
          visitId: visitId,
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
          status: status,
          xrayUrl: xrayUrlToSave,
        );
      } else {
        // Create new visit
        visitId = await medicalService.createVisit(
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
          status: status,
          xrayUrl: xrayUrlToSave,
        );
      }

      // Save tooth records
      final toothNotes = <int, String>{};
      for (var entry in _toothNoteControllers.entries) {
        final note = entry.value.text.trim();
        if (note.isNotEmpty) {
          toothNotes[entry.key] = note;
        }
      }

      await medicalService.saveToothRecords(visitId, _selectedTeeth, toothNotes);
      
      // Update follow-up date and visited status
      final assignmentService = ref.read(patientAssignmentServiceProvider);
      
      // Get current assignment
      final assignments = await SupabaseConfig.client
          .from('patient_assignments')
          .select()
          .eq('patient_id', widget.patient.id)
          .eq('doctor_id', doctorProfile.id)
          .eq('status', 'active')
          .limit(1);
      
      if (assignments.isNotEmpty) {
        // If marked as visited, update last_visit_date
        if (_markAsVisited) {
          await assignmentService.markAsVisitedForFollowUp(
            patientId: widget.patient.id,
            doctorId: doctorProfile.id,
          );
        }
        
        // Update follow-up date (can set even if marked as visited)
        if (_followUpDate != null) {
          await assignmentService.updateFollowUpDate(
            patientId: widget.patient.id,
            doctorId: doctorProfile.id,
            followUpDate: _followUpDate,
          );
        }
      }
      
      // If submitting, return patient to admin
      if (submit) {
        await _returnPatientToAdmin();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(submit 
                ? 'Visit record submitted successfully' 
                : 'Visit record saved as draft'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${submit ? 'submit' : 'save'} visit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _returnPatientToAdmin() async {
    try {
      // Get current assignment
      final assignmentService = ref.read(patientAssignmentServiceProvider);
      final currentHospital = ref.read(currentHospitalProvider);
      if (currentHospital == null) return;
      
      // Find active assignment for this patient
      final assignments = await SupabaseConfig.client
          .from('patient_assignments')
          .select()
          .eq('patient_id', widget.patient.id)
          .eq('status', 'active')
          .eq('tenant_id', currentHospital.id);
      
      if (assignments.isNotEmpty) {
        final assignmentId = assignments.first['id'];
        await assignmentService.returnToAdmin(assignmentId);
      }
    } catch (e) {
      // Silently handle - main operation succeeded
      print('Failed to return patient to admin: $e');
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
            // X-ray Attachment Section
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.image, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text(
                          'X-Ray Attachment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_xrayFileName != null || _xrayUrl != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, color: Colors.purple),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _xrayFileName ?? 'X-ray file',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  if (_xrayUrl != null)
                                    const Text(
                                      'Click view to open',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                            if (_xrayUrl != null)
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                onPressed: () => _openXray(_xrayUrl!),
                                tooltip: 'View X-ray',
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _xrayFileName = null;
                                  _xrayFilePath = null;
                                  if (widget.existingVisit == null) {
                                    _xrayUrl = null;
                                  }
                                });
                              },
                              tooltip: 'Remove X-ray',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickXrayFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_xrayFileName == null ? 'Attach X-Ray' : 'Change X-Ray'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Supported: JPG, PNG, PDF',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Follow-up Section
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Follow-Up Management',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Mark patient as visited for follow-up'),
                      subtitle: const Text('Patient has completed current follow-up visit'),
                      value: _markAsVisited,
                      onChanged: (value) {
                        setState(() {
                          _markAsVisited = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(
                        _followUpDate == null
                            ? 'Set Follow-Up Date'
                            : 'Follow-Up: ${DateFormat('MMM dd, yyyy').format(_followUpDate!)}',
                      ),
                      subtitle: _followUpDate == null
                          ? const Text('Schedule next visit')
                          : const Text('Patient will receive reminder 2 days before'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_followUpDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () {
                                setState(() => _followUpDate = null);
                              },
                              tooltip: 'Clear date',
                            ),
                          IconButton(
                            icon: Icon(
                              _followUpDate == null ? Icons.add : Icons.edit,
                              color: Colors.blue,
                            ),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _followUpDate = date);
                              }
                            },
                            tooltip: _followUpDate == null ? 'Set date' : 'Change date',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
            // Show both buttons or just submit if already submitted
            if (widget.existingVisit?.isSubmitted == true)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This record has been submitted and cannot be edited',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _saveVisit(submit: false),
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save as Draft'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _saveVisit(submit: true),
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Submit & Complete'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
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
