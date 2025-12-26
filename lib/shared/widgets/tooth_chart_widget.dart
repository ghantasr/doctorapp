import 'package:flutter/material.dart';
import '../../core/medical/medical_records_service.dart';

class ToothChartWidget extends StatefulWidget {
  final Map<int, ToothStatus> selectedTeeth;
  final Function(int toothNumber, ToothStatus status) onToothTap;
  final bool isEditable;

  const ToothChartWidget({
    super.key,
    required this.selectedTeeth,
    required this.onToothTap,
    this.isEditable = true,
  });

  @override
  State<ToothChartWidget> createState() => _ToothChartWidgetState();
}

class _ToothChartWidgetState extends State<ToothChartWidget> {
  ToothStatus _selectedStatus = ToothStatus.problem;

  Color _getToothColor(ToothStatus? status) {
    if (status == null) return Colors.grey.shade200;
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

  Color _getToothBorderColor(ToothStatus? status) {
    if (status == null) return Colors.grey.shade400;
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

  Widget _buildTooth(int number) {
    final status = widget.selectedTeeth[number];
    final isSelected = status != null;

    return GestureDetector(
      onTap: widget.isEditable
          ? () => widget.onToothTap(number, _selectedStatus)
          : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getToothColor(status),
          border: Border.all(
            color: _getToothBorderColor(status),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isEditable) ...[
          const Text(
            'Select Status:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(ToothStatus.problem, 'Problem', Icons.warning),
              _buildStatusChip(ToothStatus.inProgress, 'In Progress', Icons.pending),
              _buildStatusChip(ToothStatus.completed, 'Completed', Icons.check_circle),
              _buildStatusChip(ToothStatus.healthy, 'Healthy', Icons.favorite),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Tooth Chart (Universal Numbering System)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        // Upper jaw
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Text('Upper Jaw', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              // Right side (1-8)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('R  ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ...List.generate(8, (i) => Expanded(child: _buildTooth(8 - i))),
                ],
              ),
              const SizedBox(height: 4),
              // Left side (9-16)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(8, (i) => Expanded(child: _buildTooth(9 + i))),
                  const Text('  L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Lower jaw
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Text('Lower Jaw', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              // Right side (32-25)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('R  ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ...List.generate(8, (i) => Expanded(child: _buildTooth(32 - i))),
                ],
              ),
              const SizedBox(height: 4),
              // Left side (17-24)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(8, (i) => Expanded(child: _buildTooth(17 + i))),
                  const Text('  L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        if (!widget.isEditable && widget.selectedTeeth.isEmpty) ...[
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'No tooth records for this visit',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(ToothStatus status, String label, IconData icon) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : _getToothBorderColor(status)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = status;
          });
        }
      },
      selectedColor: _getToothBorderColor(status),
      backgroundColor: _getToothColor(status),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
