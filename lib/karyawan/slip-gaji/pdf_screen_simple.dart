import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';

class PdfSlipGajiScreenSimple extends StatefulWidget {
  final Map<String, dynamic> slipGajiData;
  final String periode;

  const PdfSlipGajiScreenSimple({
    super.key,
    required this.slipGajiData,
    required this.periode,
  });

  @override
  State<PdfSlipGajiScreenSimple> createState() =>
      _PdfSlipGajiScreenSimpleState();
}

class _PdfSlipGajiScreenSimpleState extends State<PdfSlipGajiScreenSimple> {
  String? errorMsg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColor.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColor.backgroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preview Slip Gaji',
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 18,
            color: AppColor.backgroundColor,
          ),
        ),
        centerTitle: true,
      ),
      body:
          errorMsg != null
              ? Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error Membuat PDF',
                        style: PoppinsTextStyle.bold.copyWith(fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        textAlign: TextAlign.center,
                        style: PoppinsTextStyle.regular.copyWith(fontSize: 14),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Kembali'),
                      ),
                    ],
                  ),
                ),
              )
              : FutureBuilder<Uint8List>(
                future: _generatePdf(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColor.primaryColor,
                          ),
                          SizedBox(height: 16),
                          Text('Membuat PDF...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        errorMsg = snapshot.error.toString();
                      });
                    });
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return Center(child: Text('Tidak ada data'));
                  }

                  return PdfPreview(
                    build: (format) async => snapshot.data!,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName: 'SlipGaji_${widget.periode}.pdf',
                  );
                },
              ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    try {
      print('Starting PDF generation...');

      final doc = pw.Document();

      final int totalGajiPokok = widget.slipGajiData['total_basic_salary'] ?? 0;
      final int totalTunjangan = widget.slipGajiData['total_allowance'] ?? 0;
      final int totalPotongan = widget.slipGajiData['total_deduction'] ?? 0;
      final int pajak = widget.slipGajiData['tax'] ?? 100000;
      final int totalDiterima = widget.slipGajiData['net_salary'] ?? 0;

      print('Data extracted successfully');
      print('totalGajiPokok: $totalGajiPokok');
      print('totalDiterima: $totalDiterima');

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header sederhana
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(20),
                  color: PdfColors.blue900,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'SLIP GAJI KARYAWAN',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Periode: ${widget.periode}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Info tanggal
                pw.Text(
                  'Tanggal Cetak: ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12),
                ),

                pw.SizedBox(height: 30),

                // Pendapatan
                pw.Text(
                  'PENDAPATAN',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),

                _buildRow('Gaji Pokok', totalGajiPokok),
                _buildRow('Tunjangan', totalTunjangan),
                pw.Divider(),
                _buildRow(
                  'Total Pendapatan',
                  totalGajiPokok + totalTunjangan,
                  bold: true,
                ),

                pw.SizedBox(height: 30),

                // Potongan
                pw.Text(
                  'POTONGAN',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),

                _buildRow('Potongan Keterlambatan', totalPotongan),
                _buildRow('Pajak Bulanan', pajak),
                pw.Divider(),
                _buildRow('Total Potongan', totalPotongan + pajak, bold: true),

                pw.SizedBox(height: 40),

                // Total
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(15),
                  color: PdfColors.grey300,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL GAJI DITERIMA',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(totalDiterima)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      print('Page added to document');
      final pdfData = await doc.save();
      print('PDF saved successfully, size: ${pdfData.length} bytes');

      return pdfData;
    } catch (e, stackTrace) {
      print('ERROR generating PDF: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  pw.Widget _buildRow(String label, int amount, {bool bold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
