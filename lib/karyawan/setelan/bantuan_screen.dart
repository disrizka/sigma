import 'package:flutter/material.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Bantuan",
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Butuh bantuan?",
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Kami siap membantu Anda memahami aplikasi Payroll lebih baik.",
              style: PoppinsTextStyle.regular.copyWith(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            _buildHelpItem(
              title: "Login dengan NIK & Password",
              description:
                  "Masuk menggunakan NIK dan password yang diberikan oleh admin. Anda bisa mengubah password sendiri di menu Profil > Ubah Password.",
              icon: Icons.login,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              title: "Absensi dengan Geolocation",
              description:
                  "Lakukan Check In dan Check Out di lokasi kantor atau lokasi yang diizinkan. Pastikan GPS aktif agar absensi tercatat dengan benar.",
              icon: Icons.location_on,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              title: "Lihat Slip Gaji",
              description:
                  "Cek slip gaji Anda setiap hari melalui aplikasi dengan mudah dan aman.",
              icon: Icons.receipt_long,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              title: "Lihat Riwayat Absensi",
              description:
                  "Cek seluruh riwayat absensi Anda, termasuk jam masuk, jam keluar, dan status izin atau cuti.",
              icon: Icons.history,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              title: "Ajukan Izin / Cuti",
              description:
                  "Ajukan izin atau cuti melalui aplikasi dan tunggu persetujuan dari admin.",
              icon: Icons.event_note,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PoppinsTextStyle.semiBold.copyWith(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: PoppinsTextStyle.regular.copyWith(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
