import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/report_model.dart';

/// PDF Service to generate filtered reports of drug incidents.
class PdfService {
  /// Generates a PDF containing the provided list of reports and matching filters,
  /// then triggers the system print/share dialog.
  Future<void> generateAndPrintReport({
    required List<ReportModel> reports,
    String? statusFilter,
    String? priorityFilter,
    String? categoryFilter,
    String? districtFilter,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NIZHAL - Incident Summary Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Active Filters Info
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Filters Applied:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Status: ${statusFilter ?? "All"}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(child: pw.Text('Priority: ${priorityFilter ?? "All"}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(child: pw.Text('Category: ${categoryFilter ?? "All"}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(child: pw.Text('District: ${districtFilter ?? "All"}', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Total Cases Found: ${reports.length}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.teal)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table of Reports
            pw.TableHelper.fromTextArray(
              headers: ['Report ID', 'Category', 'Priority', 'District', 'Status', 'Date'],
              data: reports.map((r) => [
                r.reportId,
                r.category,
                r.priority,
                r.district ?? '—',
                r.status,
                '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    // Show Print / Save Document UI
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Nizhal_Incident_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
