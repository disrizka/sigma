import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
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
import 'package:sigma/api/api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = const FlutterSecureStorage();

  String formattedTime = '';
  String formattedDate = '';
  Timer? timer;

  // Data user
  Map<String, dynamic>? userData;
  bool isLoadingUser = true;

  // Data statistik bulan ini
  Map<String, dynamic>? monthlyStats;
  bool isLoadingStats = true;

  // BASE URL dari api.dart
  final String _baseUrl = '$baseUrl/api';

  @override
  void initState() {
    super.initState();
    updateTime();
    getUser();
    getMonthlyStats();
    getGajiBulanIni(); //
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

  Future<void> getUser() async {
    setState(() {
      isLoadingUser = true;
    });

    try {
      final token = await storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoadingUser = false;
          userData = null;
        });
        return;
      }

      final url = Uri.parse('$_baseUrl/user');
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          userData = decoded['data'] ?? decoded;
          isLoadingUser = false;
        });
      } else {
        setState(() {
          isLoadingUser = false;
          userData = null;
        });
      }
    } catch (e) {
      print("Error getUser: $e");
      setState(() {
        isLoadingUser = false;
        userData = null;
      });
    }
  }

  Future<void> getMonthlyStats() async {
    setState(() {
      isLoadingStats = true;
    });

    try {
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        setState(() {
          isLoadingStats = false;
        });
        return;
      }

      // Gunakan endpoint baru
      final url = Uri.parse('$_baseUrl/karyawan/monthly-stats');
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('Monthly Stats Response: ${response.statusCode}');
      print('Monthly Stats Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'];

          setState(() {
            monthlyStats = {
              'cuti': data['cuti_tahun_ini'] ?? 0, // Per tahun
              'izin': data['izin_bulan_ini'] ?? 0, // Per bulan
              'alpha': data['alpha_bulan_ini'] ?? 0, // Per bulan
              'sisa_cuti': data['sisa_cuti'] ?? 12,
            };
            isLoadingStats = false;
          });
        } else {
          setState(() {
            monthlyStats = {'cuti': 0, 'izin': 0, 'alpha': 0, 'sisa_cuti': 12};
            isLoadingStats = false;
          });
        }
      } else {
        setState(() {
          monthlyStats = {'cuti': 0, 'izin': 0, 'alpha': 0, 'sisa_cuti': 12};
          isLoadingStats = false;
        });
      }
    } catch (e) {
      print("Error getMonthlyStats: $e");
      setState(() {
        monthlyStats = {'cuti': 0, 'izin': 0, 'alpha': 0, 'sisa_cuti': 12};
        isLoadingStats = false;
      });
    }
  }
  Future<void> getGajiBulanIni() async {
  try {
    final token = await storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return;

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Gunakan endpoint payslip untuk ambil gaji
    final url = Uri.parse('$_baseUrl/karyawan/payslip-live/$year/$month');
    final response = await http
        .get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    print('Gaji Response: ${response.statusCode}');
    print('Gaji Body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded['success'] == true && decoded['data'] != null) {
        setState(() {
          if (monthlyStats == null) {
            monthlyStats = {'gaji_bersih': 0, 'cuti_terpakai': 0, 'sisa_cuti': 12, 'izin': 0, 'alpha': 0};
          }
          monthlyStats!['gaji_bersih'] = decoded['data']['net_salary'] ?? 0;
        });
      }
    }
  } catch (e) {
    print("Error getGajiBulanIni: $e");
  }
}

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp. 0';

    try {
      final number =
          amount is int ? amount : int.tryParse(amount.toString()) ?? 0;
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp. ',
        decimalDigits: 0,
      );
      return formatter.format(number);
    } catch (e) {
      return 'Rp. 0';
    }
  }

  void updateTime() {
    final now = DateTime.now();
    setState(() {
      formattedTime = DateFormat('HH:mm a').format(now).toUpperCase();
      formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now);
    });
  }

  Future<void> _refreshData() async {
    await Future.wait([getUser(), getMonthlyStats(),getGajiBulanIni(),]);
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
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    // _buildSearchBox(),
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
                      const HistoryScreen(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Loading state
    if (isLoadingUser) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        height: 100,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Error state
    if (userData == null || userData!.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Gagal memuat data pengguna",
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: getUser,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Success state
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kiri: Nama dan Jabatan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${userData!['name'] ?? userData!['nama'] ?? 'User'}',
                  style: PoppinsTextStyle.bold.copyWith(
                    color: Colors.black,
                    fontSize: 24,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  userData!['jabatan'] ?? userData!['position'] ?? '-',
                  style: PoppinsTextStyle.medium.copyWith(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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
                    userData!['status'] ?? 'status',
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.green.shade50],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100, width: 1.5),
      ),
      child: Column(
        children: [
          // Bagian Gaji
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(AppImage.boxUang, width: 32, height: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gaji Bulan Ini',
                        style: PoppinsTextStyle.medium.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      isLoadingStats
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(
                            formatCurrency(monthlyStats?['gaji_bersih'] ?? 0),
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 18,
                              color: Colors.green.shade700,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bagian Statistik
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                AppImage.boxCuti,
                'Cuti',
                isLoadingStats ? '-' : '${monthlyStats?['cuti'] ?? 0}',
                Colors.blue,
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade300),
              _buildStatItem(
                AppImage.boxIzin,
                'Izin',
                isLoadingStats ? '-' : '${monthlyStats?['izin'] ?? 0}',
                Colors.orange,
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade300),
              _buildStatItem(
                AppImage.boxAlpa,
                'Tidak Hadir',
                isLoadingStats ? '-' : '${monthlyStats?['alpha'] ?? 0}',
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String iconPath,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(iconPath, width: 28, height: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: PoppinsTextStyle.medium.copyWith(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: PoppinsTextStyle.bold.copyWith(fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }

  // Widget _buildSearchBox() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(24),
  //       boxShadow: [
  //         BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
  //       ],
  //       border: Border.all(color: Colors.grey.shade300, width: 1),
  //     ),
  //     child: Row(
  //       children: [
  //         const SizedBox(width: 20),
  //         const Icon(Icons.search, color: Colors.black54),
  //         const SizedBox(width: 10),
  //         Expanded(
  //           child: TextField(
  //             decoration: InputDecoration(
  //               hintText: 'Cari fitur di sini...',
  //               hintStyle: PoppinsTextStyle.regular.copyWith(
  //                 color: Colors.grey[600],
  //                 fontSize: 13,
  //               ),
  //               border: InputBorder.none,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
              padding: const EdgeInsets.symmetric(vertical: 16),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
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
