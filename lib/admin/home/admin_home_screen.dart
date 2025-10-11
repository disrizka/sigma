import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sigma/admin/absensi-karyawan/admin_absensi_karyawan_screen.dart';
import 'package:sigma/admin/absensi-karyawan/admin_absensi_list.dart';
import 'package:sigma/admin/auth/login/login_screen.dart';
import 'package:sigma/admin/detail-gaji/admin_gaji_karyawan_screen.dart';
import 'package:sigma/admin/detail-karyawan/admin_detail_karyawan_screen.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

// --- MODEL UNTUK DATA PENGAJUAN ---
class PengajuanItem {
  final int id;
  final String namaKaryawan;
  final String nik;
  final String jenisPengajuan;
  final String alasan;
  final DateTime tanggal;
  final String? fileProof;

  PengajuanItem({
    required this.id,
    required this.namaKaryawan,
    required this.nik,
    required this.jenisPengajuan,
    required this.alasan,
    required this.tanggal,
    this.fileProof,
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
  final String _baseUrl = 'http://10.0.2.2:8000/api';

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
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _handleApproval(int id, bool isApproved) async {
    final token = await _storage.read(key: 'auth_token');
    final action = isApproved ? 'approve' : 'reject';
    final url = Uri.parse('$_baseUrl/admin/leave-requests/$id/$action');

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pendingApprovals.removeWhere((item) => item.id == id);
          });
        }
        _showSuccess(data['message']);
      } else {
        _showError(data['message'] ?? 'Gagal memproses permintaan.');
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi: $e');
    }
  }

  Future<void> _addKaryawan(Map<String, String> dataKaryawan) async {
    final token = await _storage.read(key: 'auth_token');
    final url = Uri.parse('$_baseUrl/admin/create-employee');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: dataKaryawan,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        _showSuccess('Karyawan berhasil ditambahkan!');
        _loadData();
      } else {
        String errorMessage = data['message'] ?? 'Gagal menambah karyawan.';
        if (data['errors'] != null) {
          errorMessage = (data['errors'] as Map).values.first[0];
        }
        _showError(errorMessage);
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi: $e');
    }
  }

  Future<void> _launchFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      _showError("File tidak ditemukan.");
      return;
    }

    // Gabungkan base URL dengan path file dari server
    final url = Uri.parse('http://10.0.2.2:8000/storage/$filePath');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError("Tidak bisa membuka file: $url");
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
          childAspectRatio: 1.2,
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
              onTap: () {
                _showAddKaryawanDialog();
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
                // Arahkan ke halaman DAFTAR KARYAWAN
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const AdminListAbsensiKaryawanScreen(),
                  ),
                );
                // Setelah kembali, muat ulang data dashboard
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: PoppinsTextStyle.regular.copyWith(
                fontSize: 11,
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
          Text(
            'Alasan:',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          Text(
            item.alasan,
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Diajukan: ${_formatDateTime(item.tanggal)}',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),

          // Tombol untuk melihat lampiran (hanya muncul jika ada file)
          if (item.fileProof != null && item.fileProof!.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _launchFile(item.fileProof),
              icon: Icon(
                Icons.attachment,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              label: Text(
                'Lihat Lampiran',
                style: PoppinsTextStyle.medium.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],

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

  void _showAddKaryawanDialog() {
    final nikController = TextEditingController();
    final namaController = TextEditingController();
    final passwordController = TextEditingController();
    final pekerjaanController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 8,
                  contentPadding: EdgeInsets.zero,
                  content: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with gradient
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColor.primaryColor,
                                AppColor.primaryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person_add_rounded,
                                  color: AppColor.primaryColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tambah Karyawan',
                                      style: PoppinsTextStyle.bold.copyWith(
                                        fontSize: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lengkapi data karyawan baru',
                                      style: PoppinsTextStyle.regular.copyWith(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form Content
                        Container(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTextFieldDialog(
                                  controller: nikController,
                                  label: 'NIK',
                                  hint: 'Masukkan NIK karyawan',
                                  icon: Icons.badge_rounded,
                                ),
                                const SizedBox(height: 20),
                                _buildTextFieldDialog(
                                  controller: namaController,
                                  label: 'Nama Lengkap',
                                  hint: 'Masukkan nama lengkap',
                                  icon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 20),
                                _buildTextFieldDialog(
                                  controller: passwordController,
                                  label: 'Password',
                                  hint: 'Masukkan password',
                                  icon: Icons.lock_rounded,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 20),
                                _buildTextFieldDialog(
                                  controller: pekerjaanController,
                                  label: 'Pekerjaan',
                                  hint: 'Masukkan jabatan/posisi',
                                  icon: Icons.work_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Divider
                        Container(
                          height: 1,
                          color: Colors.grey.withOpacity(0.2),
                        ),

                        // Actions
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    side: BorderSide(
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    'Batal',
                                    style: PoppinsTextStyle.semiBold.copyWith(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      isDialogLoading
                                          ? null
                                          : () async {
                                            if (nikController.text.isEmpty ||
                                                namaController.text.isEmpty ||
                                                passwordController
                                                    .text
                                                    .isEmpty ||
                                                pekerjaanController
                                                    .text
                                                    .isEmpty) {
                                              _showError(
                                                'Semua field harus diisi!',
                                              );
                                              return;
                                            }

                                            setDialogState(
                                              () => isDialogLoading = true,
                                            );

                                            final data = {
                                              'name': namaController.text,
                                              'nik': nikController.text,
                                              'password':
                                                  passwordController.text,
                                              'jabatan':
                                                  pekerjaanController.text,
                                              'status': 'aktif',
                                            };

                                            await _addKaryawan(data);

                                            if (mounted) Navigator.pop(context);
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColor.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 0,
                                    shadowColor: AppColor.primaryColor
                                        .withOpacity(0.3),
                                  ),
                                  child:
                                      isDialogLoading
                                          ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Simpan',
                                                style: PoppinsTextStyle.semiBold
                                                    .copyWith(fontSize: 15),
                                              ),
                                            ],
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildTextFieldDialog({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PoppinsTextStyle.semiBold.copyWith(
            fontSize: 13,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: PoppinsTextStyle.regular.copyWith(
              fontSize: 13,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(icon, color: AppColor.primaryColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
