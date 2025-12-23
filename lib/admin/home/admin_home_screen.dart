import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'package:sigma/admin/absensi-karyawan/admin_absensi_list.dart';
import 'package:sigma/admin/auth/login/login_screen.dart';
import 'package:sigma/admin/detail-gaji/admin_gaji_karyawan_screen.dart';
import 'package:sigma/admin/detail-karyawan/admin_detail_karyawan_screen.dart';
import 'package:sigma/admin/tambah-karyawan/tambah_karyawan_screen.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

// Update Model PengajuanItem untuk menambahkan field yang diperlukan
class PengajuanItem {
  final int id;
  final String namaKaryawan;
  final String nik;
  final String jenisPengajuan;
  final String alasan;
  final DateTime tanggal;
  final String? fileProof;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;

  PengajuanItem({
    required this.id,
    required this.namaKaryawan,
    required this.nik,
    required this.jenisPengajuan,
    required this.alasan,
    required this.tanggal,
    this.fileProof,
    this.startDate,
    this.endDate,
    this.location,
  });

  factory PengajuanItem.fromJson(Map<String, dynamic> json) {
    return PengajuanItem(
      id: json['id'],
      namaKaryawan: json['user']?['name'] ?? 'N/A',
      nik: json['user']?['nik'] ?? 'N/A',
      jenisPengajuan: json['type'] ?? 'N/A',
      alasan: json['reason'] ?? '-',
      tanggal: DateTime.parse(json['created_at']),
      fileProof: json['file_proof'],
      startDate:
          json['start_date'] != null
              ? DateTime.parse(json['start_date'])
              : null,
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      location: json['location'],
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api';

  bool _isLoading = true;
  List<PengajuanItem> _pendingApprovals = [];
  int _totalKaryawan = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- FUNGSI-FUNGSI LOGIKA & API ---

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final token = await _storage.read(key: 'auth_token');

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/admin/dashboard'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> pendingList = data['pending_requests'];

        if (mounted) {
          setState(() {
            _totalKaryawan = data['total_karyawan'];
            _pendingApprovals =
                pendingList
                    .map((item) => PengajuanItem.fromJson(item))
                    .toList();
          });
        }
      } else {
        _showError('Gagal memuat data: ${response.body}');
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApproval(int id, bool isApproved) async {
    final token = await _storage.read(key: 'auth_token');
    final action = isApproved ? 'approve' : 'reject';
    final url = Uri.parse('$_baseUrl/admin/leave-requests/$id/$action');

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print('🚀 Sending request to: $url'); // DEBUG

      final response = await http
          .put(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      print('📦 Response status: ${response.statusCode}'); // DEBUG
      print('📦 Response body: ${response.body}'); // DEBUG

      // Parse response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        print('❌ JSON Parse Error: $e'); // DEBUG
        _showError('Error parsing response: $e');
        return;
      }

      // Check status code
      if (response.statusCode == 200) {
        // Check success field
        bool isSuccess = data['success'] == true || data['success'] == 'true';

        print('✅ Success field: ${data['success']}'); // DEBUG

        if (isSuccess) {
          if (mounted) {
            setState(() {
              _pendingApprovals.removeWhere((item) => item.id == id);
            });
          }

          String message =
              data['message'] ??
              (isApproved
                  ? 'Pengajuan berhasil disetujui'
                  : 'Pengajuan berhasil ditolak');
          _showSuccess(message);

          // Reload data untuk memastikan
          await _loadData();
        } else {
          print('❌ Success is false'); // DEBUG
          _showError(data['message'] ?? 'Gagal memproses permintaan.');
        }
      } else {
        print('❌ Status code not 200: ${response.statusCode}'); // DEBUG
        _showError(
          data['message'] ??
              'Gagal memproses permintaan (Status: ${response.statusCode})',
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.pop(context);
      print('❌ Timeout: $e'); // DEBUG
      _showError('Request timeout. Silakan coba lagi.');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('❌ Exception: $e'); // DEBUG
      _showError('Terjadi kesalahan: $e');
    }
  }

  Future<void> _launchFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      _showError("File tidak ditemukan.");
      return;
    }

    final storageBase = baseUrl.replaceAll(RegExp(r'/api$'), '');
    String cleanPath = filePath
        .replaceFirst(RegExp(r'^/'), '')
        .replaceFirst(RegExp(r'^storage/'), '');
    final pdfUrl = '$storageBase/storage/$cleanPath';

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Buka File'),
            content: const Text("Ingin membuka lampiran PDF?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Buka'),
              ),
            ],
          ),
    );

    if (shouldOpen != true) return;

    try {
      final response = await http.get(Uri.parse(pdfUrl));

      if (response.statusCode != 200) {
        _showError("Gagal mengambil file.");
        return;
      }

      final bytes = response.bodyBytes;

      final doc = PdfDocument.openData(bytes);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => Scaffold(
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black87,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: const Text(
                    "Preview File",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.download_rounded,
                          color: Colors.purple.shade700,
                          size: 24,
                        ),
                        onPressed: () => _downloadPdf(pdfUrl),
                        tooltip: 'Download PDF',
                      ),
                    ),
                  ],
                ),
                body: Container(
                  color: Colors.grey[200],
                  child: PdfViewPinch(
                    controller: PdfControllerPinch(document: doc),
                  ),
                ),
              ),
        ),
      );
    } catch (e) {
      _showError("Terjadi kesalahan: $e");
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri);
      _showSuccess("Membuka file...");
    } catch (e) {
      _showError("Gagal membuka file: $e");
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final token = await _storage.read(key: 'auth_token');
    final url = Uri.parse('$_baseUrl/logout');

    try {
      await http.post(url, headers: {'Authorization': 'Bearer $token'});
    } finally {
      await _storage.delete(key: 'auth_token');
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Konfirmasi Logout',
                  style: PoppinsTextStyle.bold.copyWith(fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
              style: PoppinsTextStyle.regular.copyWith(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: PoppinsTextStyle.semiBold.copyWith(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Ya, Logout',
                  style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Logout',
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _buildStatisticsRow(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildPendingApprovals(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang, Admin! 👋',
                  style: PoppinsTextStyle.bold.copyWith(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kelola karyawan dan proses persetujuan dengan mudah',
                  style: PoppinsTextStyle.regular.copyWith(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.blue.shade800,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            iconColor: Colors.blue,
            title: 'Total Karyawan',
            value: '$_totalKaryawan',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.pending_actions,
            iconColor: Colors.orange,
            title: 'Pending',
            value: '${_pendingApprovals.length}',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: PoppinsTextStyle.bold.copyWith(
              fontSize: 24,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu Utama',
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildActionCard(
              icon: Icons.receipt_long,
              iconColor: Colors.green,
              title: 'Slip Gaji',
              subtitle: 'Cek slip gaji karyawan',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminSlipGajiListScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              icon: Icons.person_add,
              iconColor: Colors.blue,
              title: 'Tambah Karyawan',
              subtitle: 'Daftarkan karyawan baru',
              onTap: () async {
                // Navigasi ke halaman tambah karyawan
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminTambahKaryawanScreen(),
                  ),
                );
                // Reload data jika berhasil menambah karyawan
                if (result == true) {
                  _loadData();
                }
              },
            ),
            _buildActionCard(
              icon: Icons.people_outline,
              iconColor: Colors.purple,
              title: 'Data Karyawan',
              subtitle: 'Lihat semua karyawan',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDataKaryawanScreen(),
                  ),
                );
                _loadData();
              },
            ),
            _buildActionCard(
              icon: Icons.history_edu_rounded,
              iconColor: Colors.orange,
              title: 'Riwayat Absensi',
              subtitle: 'Absen per karyawan',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const AdminListAbsensiKaryawanScreen(),
                  ),
                );
                _loadData();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: PoppinsTextStyle.regular.copyWith(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Menunggu Persetujuan',
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            if (_pendingApprovals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingApprovals.length}',
                  style: PoppinsTextStyle.bold.copyWith(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _pendingApprovals.isEmpty
            ? Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada pengajuan pending',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
            : Column(
              children:
                  _pendingApprovals
                      .map((item) => _buildPendingItem(item))
                      .toList(),
            ),
      ],
    );
  }

  // Update widget _buildPendingItem
  Widget _buildPendingItem(PengajuanItem item) {
    final isIzin = item.jenisPengajuan == 'izin';
    final iconColor = isIzin ? Colors.orange : Colors.blue;
    final icon = isIzin ? Icons.info_outline : Icons.calendar_today;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama & Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaKaryawan,
                      style: PoppinsTextStyle.bold.copyWith(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'NIK: ${item.nik}',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor),
                ),
                child: Text(
                  item.jenisPengajuan.toUpperCase(),
                  style: PoppinsTextStyle.bold.copyWith(
                    fontSize: 10,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),

          // Periode Tanggal (jika ada)
          if (item.startDate != null || item.endDate != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periode',
                          style: PoppinsTextStyle.medium.copyWith(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatPeriodDate(item.startDate, item.endDate),
                          style: PoppinsTextStyle.semiBold.copyWith(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Info Pengajuan (Waktu & Lokasi)
          Row(
            children: [
              // Waktu Pengajuan
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diajukan',
                              style: PoppinsTextStyle.regular.copyWith(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _formatDateTime(item.tanggal),
                              style: PoppinsTextStyle.medium.copyWith(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Lokasi
              if (item.location != null && item.location!.isNotEmpty)
                InkWell(
                  onTap:
                      () =>
                          _showLocationMap(item.location!, 'Lokasi Pengajuan'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 24,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Alasan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Alasan',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.alasan,
                  style: PoppinsTextStyle.regular.copyWith(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Lampiran File (jika ada)
          if (item.fileProof != null && item.fileProof!.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchFile(item.fileProof),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attachment_rounded,
                      size: 16,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lihat Lampiran',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 12,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Tombol Aksi
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleApproval(item.id, false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tolak'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleApproval(item.id, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Setujui'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Fungsi helper untuk format periode tanggal
  String _formatPeriodDate(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Tanggal tidak tersedia';

    final DateFormat dayFormat = DateFormat('d', 'id_ID');
    final DateFormat monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');
    final DateFormat fullFormat = DateFormat('d MMMM yyyy', 'id_ID');

    if (start != null && end != null) {
      // Jika bulan dan tahun sama
      if (start.month == end.month && start.year == end.year) {
        return '${dayFormat.format(start)} - ${fullFormat.format(end)}';
      } else {
        return '${fullFormat.format(start)} - ${fullFormat.format(end)}';
      }
    } else if (start != null) {
      return fullFormat.format(start);
    } else {
      return fullFormat.format(end!);
    }
  }

  // Tambahkan fungsi untuk show location map (sama seperti di AdminEmployeeHistoryScreen)
  void _showLocationMap(String locationString, String title) {
    if (!locationString.contains(',')) {
      _showError('Data lokasi tidak valid.');
      return;
    }

    final parts = locationString.split(',');
    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());

    if (lat == null || lon == null) {
      _showError('Koordinat lokasi tidak valid.');
      return;
    }

    final location = LatLng(lat, lon);

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: AppColor.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: PoppinsTextStyle.bold.copyWith(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 400,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: location,
                      zoom: 17,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(title),
                        position: location,
                        infoWindow: InfoWindow(title: title),
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    }
  }
}
