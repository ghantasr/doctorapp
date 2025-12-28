import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/billing/billing_service.dart';
import '../../core/patient/patient_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../shared/widgets/hospital_selector.dart';


class CreateBillScreen extends ConsumerStatefulWidget {
  final PatientInfo patient;
  final String? visitId;

  const CreateBillScreen({
    super.key,
    required this.patient,
    this.visitId,
  });

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<BillItem> _items = [];
  final _notesController = TextEditingController();
  
  double _taxRate = 0.0;
  double _discountAmount = 0.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _taxAmount {
    return _subtotal * (_taxRate / 100);
  }

  double get _total {
    return _subtotal + _taxAmount - _discountAmount;
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _AddBillItemDialog(
        onAdd: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _generateBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
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

      final billingService = ref.read(billingServiceProvider);
      final bill = await billingService.createBill(
        patientId: widget.patient.id,
        doctorId: doctorProfile.id,
        tenantId: tenant.id,
        visitId: widget.visitId,
        items: _items,
        subtotal: _subtotal,
        tax: _taxAmount,
        discount: _discountAmount,
        totalAmount: _total,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(bill);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate bill: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Bill'),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Name: ${widget.patient.fullName}'),
                          if (widget.patient.phone != null)
                            Text('Phone: ${widget.patient.phone}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bill Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'No items added yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.description),
                          subtitle: Text(
                            'Qty: ${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Tax Rate (%)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _taxRate.toString(),
                            onChanged: (value) {
                              setState(() {
                                _taxRate = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Discount Amount (\$)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _discountAmount.toString(),
                            onChanged: (value) {
                              setState(() {
                                _discountAmount = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal', _subtotal),
                          const Divider(),
                          _buildSummaryRow('Tax', _taxAmount),
                          const Divider(),
                          _buildSummaryRow('Discount', -_discountAmount),
                          const Divider(thickness: 2),
                          _buildSummaryRow(
                            'Total',
                            _total,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Additional notes or payment terms',
                    ),
                    maxLines: 3,
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
                  onPressed: _isLoading ? null : _generateBill,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Generate Bill'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: amount < 0 ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}

class _AddBillItemDialog extends StatefulWidget {
  final Function(BillItem) onAdd;

  const _AddBillItemDialog({required this.onAdd});

  @override
  State<_AddBillItemDialog> createState() => _AddBillItemDialogState();
}

class _AddBillItemDialogState extends State<_AddBillItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bill Item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'e.g., Dental Cleaning',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null || int.parse(value) <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price *',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
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
              final quantity = int.parse(_quantityController.text);
              final unitPrice = double.parse(_unitPriceController.text);
              final item = BillItem(
                description: _descriptionController.text.trim(),
                quantity: quantity,
                unitPrice: unitPrice,
                total: quantity * unitPrice,
              );
              widget.onAdd(item);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
