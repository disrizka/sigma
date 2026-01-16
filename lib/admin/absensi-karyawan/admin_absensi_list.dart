import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sigma/admin/absensi-karyawan/admin_absensi_karyawan_screen.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';

// Model User
class UserModel {
  final int id;
  final String name;
  final String nik;
  final String jabatan;
  final String status;

  UserModel({
    required this.id,
    required this.name,
    required this.nik,
    required this.jabatan,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: (json['name'] ?? 'N/A').toString().trim(),
      nik: (json['nik'] ?? 'N/A').toString().trim(),
      jabatan: (json['jabatan'] ?? 'N/A').toString().trim(),
      status: (json['status'] ?? 'aktif').toString().trim().toLowerCase(),
    );
  }
}

class AdminListAbsensiKaryawanScreen extends StatefulWidget {
  const AdminListAbsensiKaryawanScreen({super.key});

  @override
  State<AdminListAbsensiKaryawanScreen> createState() =>
      _AdminListAbsensiKaryawanScreenState();
}

class _AdminListAbsensiKaryawanScreenState
    extends State<AdminListAbsensiKaryawanScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api';
  bool _isLoading = true;
  List<UserModel> _employees = [];

  // Getter untuk karyawan aktif dan non-aktif yang sudah diurutkan berdasarkan NIK
  List<UserModel> get _activeEmployees {
    final actives = _employees.where((e) => e.status == 'aktif').toList();
    actives.sort((a, b) => a.nik.compareTo(b.nik));
    return actives;
  }

  List<UserModel> get _inactiveEmployees {
    final inactives = _employees.where((e) => e.status == 'tidak_aktif').toList();
    inactives.sort((a, b) => a.nik.compareTo(b.nik));
    return inactives;
  }

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  // API Logic
  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'auth_token');

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/admin/employees'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Cek apakah response body kosong
        if (response.body.isEmpty) {
          if (mounted) {
            setState(() {
              _employees = [];
            });
          }
          _showSnackBar('Response kosong dari server', isError: true);
          return;
        }

        // Parse JSON dengan error handling
        try {
          final dynamic jsonData = json.decode(response.body);
          print('JSON Type: ${jsonData.runtimeType}');
          
          // Cek apakah data adalah List
          if (jsonData is List) {
            if (mounted) {
              setState(() {
                _employees = [];
                for (var i = 0; i < jsonData.length; i++) {
                  try {
                    // Pastikan item adalah Map
                    if (jsonData[i] is Map<String, dynamic>) {
                      final Map<String, dynamic> item = Map<String, dynamic>.from(jsonData[i]);
                      
                      // Hanya ambil field yang dibutuhkan, abaikan field lain
                      final cleanData = {
                        'id': item['id'],
                        'name': item['name'],
                        'nik': item['nik'],
                        'jabatan': item['jabatan'],
                        'status': item['status'],
                      };
                      
                      final employee = UserModel.fromJson(cleanData);
                      _employees.add(employee);
                      print('✓ Successfully parsed: ${employee.name} (${employee.nik})');
                    }
                  } catch (e) {
                    print('✗ Error parsing employee at index $i');
                    print('Data: ${jsonData[i]}');
                    print('Error: $e');
                    // Skip employee yang error, lanjut ke yang berikutnya
                  }
                }
                print('Total employees loaded: ${_employees.length}');
              });
            }
          } else {
            // Jika response bukan List, cek apakah ada key 'data'
            if (jsonData is Map && jsonData.containsKey('data')) {
              final List<dynamic> data = jsonData['data'];
              if (mounted) {
                setState(() {
                  _employees = [];
                  for (var i = 0; i < data.length; i++) {
                    try {
                      if (data[i] is Map<String, dynamic>) {
                        final Map<String, dynamic> item = Map<String, dynamic>.from(data[i]);
                        
                        // Hanya ambil field yang dibutuhkan
                        final cleanData = {
                          'id': item['id'],
                          'name': item['name'],
                          'nik': item['nik'],
                          'jabatan': item['jabatan'],
                          'status': item['status'],
                        };
                        
                        final employee = UserModel.fromJson(cleanData);
                        _employees.add(employee);
                        print('✓ Successfully parsed: ${employee.name} (${employee.nik})');
                      }
                    } catch (e) {
                      print('✗ Error parsing employee at index $i');
                      print('Data: ${data[i]}');
                      print('Error: $e');
                      // Skip employee yang error
                    }
                  }
                  print('Total employees loaded: ${_employees.length}');
                });
              }
            } else {
              _showSnackBar('Format data tidak sesuai.', isError: true);
            }
          }
        } catch (e) {
          print('JSON Parse Error: $e');
          print('Response body: ${response.body}');
          _showSnackBar('Gagal memproses data: ${e.toString()}', isError: true);
        }
      } else if (response.statusCode == 401) {
        _showSnackBar('Sesi login berakhir, silakan login kembali', isError: true);
      } else {
        _showSnackBar('Gagal memuat data karyawan. Status: ${response.statusCode}', isError: true);
      }
    } on TimeoutException catch (_) {
      _showSnackBar('Koneksi timeout, coba lagi', isError: true);
    } on http.ClientException catch (e) {
      _showSnackBar('Kesalahan koneksi: ${e.message}', isError: true);
    } catch (e) {
      print('General Error: $e');
      _showSnackBar('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // UI Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeaderCard(),
          Expanded(
            child:
                _isLoading
                    ? _buildLoadingState()
                    : _employees.isEmpty
                    ? _buildEmptyState()
                    : _buildEmployeeList(),
          ),
        ],
      ),
    );
  }

  // AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Absensi Karyawan',
        style: PoppinsTextStyle.bold.copyWith(
          color: Colors.black87,
          fontSize: 20,
        ),
      ),
    );
  }

  //hanya karyawan aktif
  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColor.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Karyawan Aktif',
                  style: PoppinsTextStyle.medium.copyWith(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_activeEmployees.length}',
                  style: PoppinsTextStyle.bold.copyWith(
                    fontSize: 32,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Aktif',
                  style: PoppinsTextStyle.semiBold.copyWith(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Loading State
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.black87),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Data Karyawan',
            style: PoppinsTextStyle.bold.copyWith(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data karyawan akan muncul di sini',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Employee List dengan Pemisahan Aktif dan Non-Aktif
  Widget _buildEmployeeList() {
    return RefreshIndicator(
      onRefresh: _fetchEmployees,
      color: AppColor.primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          // Karyawan Aktif
          if (_activeEmployees.isNotEmpty) ...[
            ..._activeEmployees.asMap().entries.map(
              (entry) => _buildEmployeeCard(entry.value, entry.key),
            ),
          ],

          // Divider dan Header Non-Aktif
          if (_inactiveEmployees.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInactiveHeader(),
            const SizedBox(height: 16),
            ..._inactiveEmployees.asMap().entries.map(
              (entry) => _buildEmployeeCard(entry.value, entry.key),
            ),
          ],
        ],
      ),
    );
  }

  // Header untuk Section Non-Aktif
  Widget _buildInactiveHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFFD32F2F).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFD32F2F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person_off_rounded,
              color: Color(0xFFD32F2F),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Karyawan Non-Aktif',
                  style: PoppinsTextStyle.bold.copyWith(
                    fontSize: 16,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${_inactiveEmployees.length} karyawan',
                  style: PoppinsTextStyle.medium.copyWith(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_inactiveEmployees.length}',
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(UserModel employee, int index) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFFEA580C),
    ];
    final avatarColor = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AdminEmployeeHistoryScreen(
                      userId: employee.id,
                      userName: employee.name,
                    ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      employee.name.isNotEmpty
                          ? employee.name[0].toUpperCase()
                          : '?',
                      style: PoppinsTextStyle.bold.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Karyawan
                      Text(
                        employee.name,
                        style: PoppinsTextStyle.bold.copyWith(
                          fontSize: 16,
                          color: Colors.black87,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // NIK
                      _buildInfoRow(
                        icon: Icons.badge_outlined,
                        value: employee.nik,
                        color: const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 8),
                      // Jenis Pekerjaan
                      _buildInfoRow(
                        icon: Icons.work_outline_rounded,
                        value: employee.jabatan,
                        color: avatarColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 13,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}