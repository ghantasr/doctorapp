import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'prescription_service.dart';

class PrescriptionPdfService {
  static Future<pw.Document> generatePrescriptionPdf(Prescription prescription) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Clinic Info
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (prescription.tenant != null) ...[
                      pw.Text(
                        prescription.tenant!.name,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      if (prescription.tenant!.address != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          prescription.tenant!.address!,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 12),
                    ],
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (prescription.doctor != null) ...[
                              pw.Text(
                                'Dr. ${prescription.doctor!.fullName}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (prescription.doctor!.specialty.isNotEmpty) ...[
                                pw.Text(
                                  prescription.doctor!.specialty,
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                              if (prescription.doctor!.licenseNumber.isNotEmpty) ...[
                                pw.Text(
                                  'Reg. No: ${prescription.doctor!.licenseNumber}',
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'PRESCRIPTION',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              prescription.prescriptionNumber,
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Date',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              dateFormat.format(prescription.prescriptionDate),
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Patient Information
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Patient Information',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      prescription.patientName ?? 'Unknown Patient',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Medications
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(6),
                          topRight: pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            '℞ ',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'Medications',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Column(
                        children: prescription.medications.asMap().entries.map((entry) {
                          final index = entry.key;
                          final med = entry.value;
                          return pw.Column(
                            children: [
                              if (index > 0) pw.Divider(height: 20),
                              _buildMedicationItem(med, index + 1),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Instructions
              if (prescription.instructions != null && prescription.instructions!.isNotEmpty) ...[
                pw.SizedBox(height: 30),
                pw.Text(
                  'General Instructions',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    border: pw.Border.all(color: PdfColors.amber300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    prescription.instructions!,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'This is a computer-generated prescription',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Doctor Signature: __________________',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildMedicationItem(Medication med, int index) {
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '$index',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Text(
                  med.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMedicationDetail('Dosage', med.dosage),
                _buildMedicationDetail('Frequency', med.frequency),
                _buildMedicationDetail('Duration', med.duration),
                if (med.instructions != null && med.instructions!.isNotEmpty)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 4),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Note: ',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            med.instructions!,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicationDetail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printPrescription(Prescription prescription) async {
    final pdf = await generatePrescriptionPdf(prescription);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<void> sharePrescription(Prescription prescription) async {
    final pdf = await generatePrescriptionPdf(prescription);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${prescription.prescriptionNumber}.pdf',
    );
  }
}
