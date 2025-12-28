import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'billing_service.dart';

class BillPdfService {
  static Future<pw.Document> generateBillPdf(Bill bill) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (bill.tenant != null) ...[
                        pw.Text(
                          bill.tenant!.name,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        if (bill.tenant!.address != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            bill.tenant!.address!,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ],
                      pw.SizedBox(height: 8),
                      if (bill.doctor != null) ...[
                        pw.Text(
                          'Dr. ${bill.doctor!.fullName}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (bill.doctor!.specialty.isNotEmpty) ...[
                          pw.Text(
                            bill.doctor!.specialty,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                        if (bill.doctor!.licenseNumber.isNotEmpty) ...[
                          pw.Text(
                            'Reg. No: ${bill.doctor!.licenseNumber}',
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
                        'MEDICAL BILL',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        bill.billNumber,
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
                        dateFormat.format(bill.createdAt),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(height: 30, thickness: 2),

              // Patient Information
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
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
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      bill.patientName ?? 'Unknown Patient',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Items Table
              pw.Text(
                'Bill Items',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rate',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Items
                  ...bill.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item.description),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormat.format(item.unitPrice),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormat.format(item.total),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal', currencyFormat.format(bill.subtotal)),
                        if (bill.taxAmount > 0)
                          _buildTotalRow('Tax', currencyFormat.format(bill.taxAmount)),
                        if (bill.discount > 0)
                          _buildTotalRow('Discount', '-${currencyFormat.format(bill.discount)}'),
                        pw.Divider(thickness: 2),
                        _buildTotalRow(
                          'Total Amount',
                          currencyFormat.format(bill.totalAmount),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Notes
              if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 30),
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(bill.notes!),
                ),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Thank you for your visit!',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isBold ? 14 : 12,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isBold ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printBill(Bill bill) async {
    final pdf = await generateBillPdf(bill);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<void> shareBill(Bill bill) async {
    final pdf = await generateBillPdf(bill);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${bill.billNumber}.pdf',
    );
  }
}
