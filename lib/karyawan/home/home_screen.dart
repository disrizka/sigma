import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sigma/admin/auth/login/login_screen.dart';
import 'package:sigma/karyawan/check-in/checkin_screen.dart';
import 'package:sigma/karyawan/check-out/checkout_screen.dart';
import 'package:sigma/karyawan/cuti/cuti_screen.dart';
import 'package:sigma/karyawan/izin/izin_screen.dart';
import 'package:sigma/karyawan/riwayat_hadir/riwayat_hadir_screen.dart';
import 'package:sigma/karyawan/slip-gaji/slipgaji_screen.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String formattedTime = '';
  String formattedDate = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    updateTime();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => updateTime(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void updateTime() {
    final now = DateTime.now();
    setState(() {
      formattedTime = DateFormat('HH:mm a').format(now).toUpperCase();
      formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed:
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppImage.logo, height: 60),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStatusCard(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSearchBox(),
                  const SizedBox(height: 24),
                  _buildLiveAttendance(formattedTime, formattedDate),
                  const SizedBox(height: 16),
                  _buildCheckButtons(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Fitur',
                style: PoppinsTextStyle.bold.copyWith(
                  color: Colors.black,
                  fontSize: 18,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFeatureItem(
                    context,
                    'Slip Gaji',
                    AppImage.fitur1,
                    SlipGajiScreen(),
                  ),
                  _buildFeatureItem(
                    context,
                    'Pengajuan\nIzin',
                    AppImage.fitur2,
                    IzinScreen(),
                  ),
                  _buildFeatureItem(
                    context,
                    'Pengajuan\nCuti',
                    AppImage.fitur3,
                    CutiScreen(),
                  ),
                  _buildFeatureItem(
                    context,
                    'Riwayat\nKehadiran',
                    AppImage.fitur4,
                    HistoryScreen(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kiri: Nama dan Jabatan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, Lily',
                style: PoppinsTextStyle.bold.copyWith(
                  color: Colors.black,
                  fontSize: 24,
                ),
              ),
              Text(
                'Software Engineering',
                style: PoppinsTextStyle.medium.copyWith(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Kanan: Status
          Row(
            children: [
              Image.asset(AppImage.status, width: 32, height: 32),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: PoppinsTextStyle.bold.copyWith(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'Aktif',
                    style: PoppinsTextStyle.medium.copyWith(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
        ],
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child: Image.asset(AppImage.boxUang, width: 30, height: 30),
                  ),
                ),
                Flexible(
                  child: Text(
                    'Rp. 98.000',
                    style: PoppinsTextStyle.bold.copyWith(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1.5,
            height: 60,
            color: Colors.grey.withOpacity(0.3),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            flex: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusItem(AppImage.boxCuti, 'Cuti', '2'),
                _buildStatusItem(AppImage.boxIzin, 'Izin', '-'),
                _buildStatusItem(AppImage.boxAlpa, 'Tidak Hadir', '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String iconPath, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(iconPath, width: 40, height: 40),
        const SizedBox(height: 8),
        Text(
          label,
          style: PoppinsTextStyle.medium.copyWith(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          const Icon(Icons.search, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari fitur di sini...',
                hintStyle: PoppinsTextStyle.regular.copyWith(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String title,
    String iconPath,
    Widget? screen,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur ini belum tersedia'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            width: 80,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5),
              ],
            ),
            child: Center(
              child: Image.asset(
                iconPath,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 11,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveAttendance(String time, String date) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            time,
            style: PoppinsTextStyle.bold.copyWith(
              color: Colors.black,
              fontSize: 48,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: PoppinsTextStyle.regular.copyWith(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckinScreen()),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              "Absen Masuk",
              style: PoppinsTextStyle.semiBold.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              "Absen Pulang",
              style: PoppinsTextStyle.semiBold.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
