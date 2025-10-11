import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sigma/admin/absensi-karyawan/admin_absensi_karyawan_screen.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';

// Model untuk menampung data user dari API
class UserModel {
  final int id;
  final String name;
  final String nik;
  final String jabatan;

  UserModel({
    required this.id,
    required this.name,
    required this.nik,
    required this.jabatan,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? 'N/A',
      nik: json['nik'] ?? 'N/A',
      jabatan: json['jabatan'] ?? 'N/A',
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
  final String _baseUrl = 'http://10.0.2.2:8000/api';
  bool _isLoading = true;
  List<UserModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  // --- FUNGSI-FUNGSI LOGIKA & API ---

  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
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

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _employees = data.map((item) => UserModel.fromJson(item)).toList();
          });
        }
      } else {
        _showSnackBar('Gagal memuat data karyawan.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
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

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        toolbarHeight: 100,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Absensi Karyawan',
          style: PoppinsTextStyle.bold.copyWith(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Section dengan Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Karyawan',
                          style: PoppinsTextStyle.medium.copyWith(
                            fontSize: 14,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_employees.length}',
                          style: PoppinsTextStyle.bold.copyWith(
                            fontSize: 28,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColor.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Aktif',
                          style: PoppinsTextStyle.semiBold.copyWith(
                            fontSize: 12,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List Section
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.black87),
                    )
                    : _employees.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _fetchEmployees,
                      color: Colors.black87,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _employees.length,
                        itemBuilder: (context, index) {
                          final employee = _employees[index];
                          return _buildEmployeeCard(employee, index);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

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
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(UserModel employee, int index) {
    // Warna avatar berdasarkan index (nuansa abu-abu)
    final colors = [
      const Color(0xFF00C853), // hijau segar
      const Color(0xFF0091EA), // biru cerah
      const Color(0xFF607D8B), // abu kebiruan netral
      const Color(0xFFAD1457), // merah keunguan lembut
      const Color(0xFF00ACC1), // biru toska lembut
    ];
    final avatarColor = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(16),
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

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 14,
                                  color: AppColor.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  employee.nik,
                                  style: PoppinsTextStyle.medium.copyWith(
                                    fontSize: 12,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                employee.jabatan,
                                style: PoppinsTextStyle.medium.copyWith(
                                  fontSize: 11,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Container(
                  padding: const EdgeInsets.all(10),

                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
