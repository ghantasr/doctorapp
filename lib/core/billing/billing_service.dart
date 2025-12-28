import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';
import '../patient/patient_service.dart';
import '../doctor/doctor_service.dart';
import '../tenant/tenant.dart';

class BillItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  BillItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
    };
  }

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      description: json['description'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}

class Bill {
  final String id;
  final String patientId;
  final String doctorId;
  final String tenantId;
  final String? visitId;
  final String billNumber;
  final DateTime billDate;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double totalAmount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  
  // Populated fields
  final PatientInfo? patient;
  final DoctorProfile? doctor;
  final Tenant? tenant;

  Bill({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.tenantId,
    this.visitId,
    required this.billNumber,
    required this.billDate,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.totalAmount,
    required this.paymentStatus,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.patient,
    this.doctor,
    this.tenant,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?)
        ?.map((item) => BillItem.fromJson(item as Map<String, dynamic>))
        .toList() ?? [];

    return Bill(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      tenantId: json['tenant_id'],
      visitId: json['visit_id'],
      billNumber: json['bill_number'],
      billDate: DateTime.parse(json['bill_date']),
      items: itemsList,
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isPaid => paymentStatus == 'paid';
  bool get isUnpaid => paymentStatus == 'unpaid';
  bool get isPartiallyPaid => paymentStatus == 'partial';
  
  String? get patientName {
    if (patient != null) {
      return '${patient!.firstName} ${patient!.lastName}'.trim();
    }
    return null;
  }
  
  double get taxAmount => tax;
}

class BillingService {
  final _client = SupabaseConfig.client;

  Future<String> generateBillNumber(String tenantId) async {
    try {
      // Get the next bill number
      final result = await _client.rpc('nextval', params: {'sequence_name': 'bill_number_seq'});
      final number = result as int;
      return 'BILL-${tenantId.substring(0, 4).toUpperCase()}-$number';
    } catch (e) {
      // Fallback to timestamp-based number
      return 'BILL-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<Bill> createBill({
    required String patientId,
    required String doctorId,
    required String tenantId,
    String? visitId,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double totalAmount,
    String? notes,
  }) async {
    try {
      final billNumber = await generateBillNumber(tenantId);
      
      final response = await _client
          .from('bills')
          .insert({
            'patient_id': patientId,
            'doctor_id': doctorId,
            'tenant_id': tenantId,
            'visit_id': visitId,
            'bill_number': billNumber,
            'bill_date': DateTime.now().toIso8601String().split('T')[0],
            'items': items.map((item) => item.toJson()).toList(),
            'subtotal': subtotal,
            'tax': tax,
            'discount': discount,
            'total_amount': totalAmount,
            'payment_status': 'unpaid',
            'notes': notes,
          })
          .select()
          .single();

      return Bill.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create bill: $e');
    }
  }

  Future<void> updatePaymentStatus({
    required String billId,
    required String status,
    String? paymentMethod,
  }) async {
    try {
      await _client.from('bills').update({
        'payment_status': status,
        'payment_method': paymentMethod,
      }).eq('id', billId);
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  Future<List<Bill>> getPatientBills(String patientId) async {
    try {
      final response = await _client
          .from('bills')
          .select('*, patients(id, first_name, last_name), doctors(id, first_name, last_name, specialty, license_number), tenants(id, name, address)')
          .eq('patient_id', patientId)
          .order('bill_date', ascending: false);

      return (response as List).map((json) {
        final bill = Bill.fromJson(json);
        final patientData = json['patients'];
        final doctorData = json['doctors'];
        final tenantData = json['tenants'];
        
        return Bill(
          id: bill.id,
          patientId: bill.patientId,
          doctorId: bill.doctorId,
          tenantId: bill.tenantId,
          visitId: bill.visitId,
          billNumber: bill.billNumber,
          billDate: bill.billDate,
          items: bill.items,
          subtotal: bill.subtotal,
          tax: bill.tax,
          discount: bill.discount,
          totalAmount: bill.totalAmount,
          paymentStatus: bill.paymentStatus,
          paymentMethod: bill.paymentMethod,
          notes: bill.notes,
          createdAt: bill.createdAt,
          patient: patientData != null ? PatientInfo(
            id: patientData['id'],
            firstName: patientData['first_name'] ?? '',
            lastName: patientData['last_name'] ?? '',
            email: '',
            phone: '',
            createdAt: DateTime.now(),
          ) : null,
          doctor: doctorData != null ? DoctorProfile(
            id: doctorData['id'],
            firstName: doctorData['first_name'] ?? '',
            lastName: doctorData['last_name'] ?? '',
            specialty: doctorData['specialty'] ?? '',
            licenseNumber: doctorData['license_number'] ?? '',
            tenantId: bill.tenantId,
            userId: '',
          ) : null,
          tenant: tenantData != null ? Tenant(
            id: tenantData['id'],
            name: tenantData['name'] ?? '',
            address: tenantData['address'],
          ) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch patient bills: $e');
    }
  }

  Future<List<Bill>> getDoctorBills(String doctorId) async {
    try {
      final response = await _client
          .from('bills')
          .select('*, patients(id, first_name, last_name), doctors(id, first_name, last_name, specialty, license_number), tenants(id, name, address)')
          .eq('doctor_id', doctorId)
          .order('bill_date', ascending: false);

      return (response as List).map((json) {
        final bill = Bill.fromJson(json);
        final patientData = json['patients'];
        final doctorData = json['doctors'];
        final tenantData = json['tenants'];
        
        return Bill(
          id: bill.id,
          patientId: bill.patientId,
          doctorId: bill.doctorId,
          tenantId: bill.tenantId,
          visitId: bill.visitId,
          billNumber: bill.billNumber,
          billDate: bill.billDate,
          items: bill.items,
          subtotal: bill.subtotal,
          tax: bill.tax,
          discount: bill.discount,
          totalAmount: bill.totalAmount,
          paymentStatus: bill.paymentStatus,
          paymentMethod: bill.paymentMethod,
          notes: bill.notes,
          createdAt: bill.createdAt,
          patient: patientData != null ? PatientInfo(
            id: patientData['id'],
            firstName: patientData['first_name'] ?? '',
            lastName: patientData['last_name'] ?? '',
            email: '',
            phone: '',
            createdAt: DateTime.now(),
          ) : null,
          doctor: doctorData != null ? DoctorProfile(
            id: doctorData['id'],
            firstName: doctorData['first_name'] ?? '',
            lastName: doctorData['last_name'] ?? '',
            specialty: doctorData['specialty'] ?? '',
            licenseNumber: doctorData['license_number'] ?? '',
            tenantId: bill.tenantId,
            userId: '',
          ) : null,
          tenant: tenantData != null ? Tenant(
            id: tenantData['id'],
            name: tenantData['name'] ?? '',
            address: tenantData['address'],
          ) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch doctor bills: $e');
    }
  }

  Future<Bill?> getBillById(String billId) async {
    try {
      final response = await _client
          .from('bills')
          .select()
          .eq('id', billId)
          .maybeSingle();

      if (response == null) return null;
      return Bill.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch bill: $e');
    }
  }

  Stream<List<Bill>> getPatientBillsStream(String patientId) {
    return _client
        .from('bills')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('bill_date', ascending: false)
        .asyncMap((rows) async {
          final List<Bill> bills = [];
          
          for (final row in rows) {
            // Fetch related data for each bill
            final patientData = await _client
                .from('patients')
                .select('id, first_name, last_name')
                .eq('id', row['patient_id'])
                .maybeSingle();
            
            final doctorData = await _client
                .from('doctors')
                .select('id, first_name, last_name, specialty, license_number')
                .eq('id', row['doctor_id'])
                .maybeSingle();
            
            final tenantData = await _client
                .from('tenants')
                .select('id, name, address')
                .eq('id', row['tenant_id'])
                .maybeSingle();
            
            final bill = Bill.fromJson(row);
            
            bills.add(Bill(
              id: bill.id,
              patientId: bill.patientId,
              doctorId: bill.doctorId,
              tenantId: bill.tenantId,
              visitId: bill.visitId,
              billNumber: bill.billNumber,
              billDate: bill.billDate,
              items: bill.items,
              subtotal: bill.subtotal,
              tax: bill.tax,
              discount: bill.discount,
              totalAmount: bill.totalAmount,
              paymentStatus: bill.paymentStatus,
              paymentMethod: bill.paymentMethod,
              notes: bill.notes,
              createdAt: bill.createdAt,
              patient: patientData != null ? PatientInfo(
                id: patientData['id'],
                firstName: patientData['first_name'] ?? '',
                lastName: patientData['last_name'] ?? '',
                email: '',
                phone: '',
                createdAt: DateTime.now(),
              ) : null,
              doctor: doctorData != null ? DoctorProfile(
                id: doctorData['id'],
                firstName: doctorData['first_name'] ?? '',
                lastName: doctorData['last_name'] ?? '',
                specialty: doctorData['specialty'] ?? '',
                licenseNumber: doctorData['license_number'] ?? '',
                tenantId: bill.tenantId,
                userId: '',
              ) : null,
              tenant: tenantData != null ? Tenant(
                id: tenantData['id'],
                name: tenantData['name'] ?? '',
                address: tenantData['address'],
              ) : null,
            ));
          }
          
          return bills;
        });
  }
}

final billingServiceProvider = Provider<BillingService>((ref) => BillingService());

final patientBillsProvider = StreamProvider.family<List<Bill>, String>((ref, patientId) {
  final service = ref.watch(billingServiceProvider);
  return service.getPatientBillsStream(patientId);
});

final doctorBillsProvider = FutureProvider.family<List<Bill>, String>((ref, doctorId) async {
  final service = ref.watch(billingServiceProvider);
  return service.getDoctorBills(doctorId);
});
