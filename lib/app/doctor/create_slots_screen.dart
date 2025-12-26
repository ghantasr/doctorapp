import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/supabase/supabase_config.dart';

class CreateSlotsScreen extends ConsumerStatefulWidget {
  const CreateSlotsScreen({super.key});

  @override
  ConsumerState<CreateSlotsScreen> createState() => _CreateSlotsScreenState();
}

class _CreateSlotsScreenState extends ConsumerState<CreateSlotsScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _slotDuration = 30;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 17, minute: 0),
    );

    if (picked != null) {
      // Validate end time is after start time
      if (_startTime != null) {
        final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
        final endMinutes = picked.hour * 60 + picked.minute;
        
        if (endMinutes <= startMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      setState(() {
        _endTime = picked;
      });
    }
  }

  List<DateTime> _generateSlots() {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      return [];
    }

    final slots = <DateTime>[];
    final date = _selectedDate!;
    
    // Create DateTime for start
    var current = DateTime(
      date.year,
      date.month,
      date.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    // Create DateTime for end
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    // Generate slots
    while (current.add(Duration(minutes: _slotDuration)).isBefore(end) || 
           current.add(Duration(minutes: _slotDuration)).isAtSameMomentAs(end)) {
      slots.add(current);
      current = current.add(Duration(minutes: _slotDuration));
    }

    return slots;
  }

  Future<void> _createSlots() async {
    final slots = _generateSlots();
    
    if (slots.isEmpty) {
      setState(() {
        _errorMessage = 'Please select date and time range';
      });
      return;
    }

    final profileAsync = ref.read(doctorProfileProvider);
    final profile = profileAsync.value;
    
    if (profile == null) {
      setState(() {
        _errorMessage = 'Doctor profile not found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create all slots in batch
      final records = slots.map((slot) => {
        'tenant_id': profile.tenantId,
        'doctor_id': profile.id,
        'patient_id': null,
        'appointment_date': slot.toUtc().toIso8601String(),
        'duration_minutes': _slotDuration,
        'status': 'available',
      }).toList();

      await SupabaseConfig.client.from('appointments').insert(records);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${slots.length} slots created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create slots: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Appointment Slots'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Set Your Availability',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create multiple appointment slots for a specific time range.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate == null
                          ? 'Choose Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Time Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectStartTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _startTime == null
                                ? 'Start Time'
                                : _startTime!.format(context),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to', style: TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectEndTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _endTime == null
                                ? 'End Time'
                                : _endTime!.format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Slot Duration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _slotDuration,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes')),
                      DropdownMenuItem(value: 45, child: Text('45 minutes')),
                      DropdownMenuItem(value: 60, child: Text('1 hour')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _slotDuration = value ?? 30;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (slots.isNotEmpty) ...[
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '${slots.length} slots will be created',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Preview:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slots.take(10).map((slot) {
                        return Chip(
                          label: Text(TimeOfDay.fromDateTime(slot).format(context)),
                          backgroundColor: Colors.white,
                        );
                      }).toList(),
                    ),
                    if (slots.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... and ${slots.length - 10} more',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: slots.isEmpty || _isLoading ? null : _createSlots,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle),
            label: const Text('Create Slots'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
