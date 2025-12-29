import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';

class PdfSlipGajiScreen extends StatelessWidget {
  final Map<String, dynamic> slipGajiData;
  final String periode;

  const PdfSlipGajiScreen({
    super.key,
    required this.slipGajiData,
    required this.periode,
  });

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
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'SlipGaji_$periode.pdf',
        onError: (context, error) {
          // Tampilkan error jika ada
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Gagal membuat PDF',
                  style: PoppinsTextStyle.bold.copyWith(fontSize: 16),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: PoppinsTextStyle.regular.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    try {
      final doc = pw.Document();

      // Pastikan data tidak null dengan default value
      final int totalGajiPokok = slipGajiData['total_basic_salary'] ?? 0;
      final int totalTunjangan = slipGajiData['total_allowance'] ?? 0;
      final int totalPotongan = slipGajiData['total_deduction'] ?? 0;
      final int pajak = slipGajiData['tax'] ?? 100000;
      final int totalDiterima = slipGajiData['net_salary'] ?? 0;
      final int totalPendapatan = totalGajiPokok + totalTunjangan;
      final int totalPengurangan = totalPotongan + pajak;

      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SLIP GAJI KARYAWAN',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Periode: $periode',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Info Karyawan
                if (slipGajiData['employee_name'] != null) ...[
                  _buildInfoRow('Nama Karyawan', slipGajiData['employee_name'].toString()),
                  pw.SizedBox(height: 5),
                ],
                if (slipGajiData['employee_id'] != null) ...[
                  _buildInfoRow('ID Karyawan', slipGajiData['employee_id'].toString()),
                  pw.SizedBox(height: 5),
                ],

                _buildInfoRow(
                  'Tanggal Cetak',
                  DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                ),

                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 15),

                // Pendapatan
                pw.Text(
                  'PENDAPATAN',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildAmountRow('Gaji Pokok', totalGajiPokok),
                _buildAmountRow('Tunjangan Makan & Transport', totalTunjangan),
                pw.Divider(thickness: 1),
                _buildAmountRow(
                  'Total Pendapatan',
                  totalPendapatan,
                  isBold: true,
                ),

                pw.SizedBox(height: 20),

                // Potongan
                pw.Text(
                  'POTONGAN',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildAmountRow('Potongan Keterlambatan', totalPotongan),
                _buildAmountRow('Pajak Bulanan', pajak),
                pw.Divider(thickness: 1),
                _buildAmountRow('Total Potongan', totalPengurangan, isBold: true),

                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),

                // Total Diterima
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL GAJI DITERIMA',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(totalDiterima)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Catatan: Slip gaji ini dibuat secara otomatis oleh sistem.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Untuk informasi lebih lanjut, hubungi HRD.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            );
          },
        ),
      );

      return await doc.save();
    } catch (e) {
      print('Error generating PDF: $e');
      // Buat PDF error page
      final errorDoc = pw.Document();
      errorDoc.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Error: $e'),
          ),
        ),
      );
      return await errorDoc.save();
    }
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Container(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(fontSize: 10)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAmountRow(String label, int amount, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}