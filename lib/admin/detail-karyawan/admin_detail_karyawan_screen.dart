import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_color.dart';

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
      id: json['id'],
      name: json['name'] ?? 'N/A',
      nik: json['nik'] ?? 'N/A',
      jabatan: json['jabatan'] ?? 'N/A',
      status: json['status'] ?? 'aktif',
    );
  }
}

class AdminDataKaryawanScreen extends StatefulWidget {
  const AdminDataKaryawanScreen({super.key});

  @override
  State<AdminDataKaryawanScreen> createState() =>
      _AdminDataKaryawanScreenState();
}

class _AdminDataKaryawanScreenState extends State<AdminDataKaryawanScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api';
  bool _isLoading = true;
  List<UserModel> _employees = [];

  // Getter untuk karyawan aktif dan non-aktif
  List<UserModel> get _activeEmployees =>
      _employees.where((e) => e.status == 'aktif').toList();
  
  List<UserModel> get _inactiveEmployees =>
      _employees.where((e) => e.status == 'tidak_aktif').toList();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

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

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(
            () =>
                _employees =
                    data.map((item) => UserModel.fromJson(item)).toList(),
          );
        }
      } else {
        _showSnackBar('Gagal memuat data karyawan.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmployeeStatus(int id, String newStatus) async {
    final token = await _storage.read(key: 'auth_token');
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/employees/$id/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': newStatus}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        _showSnackBar(data['message']);
        _fetchEmployees();
      } else {
        _showSnackBar(data['message'], isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    }
  }

  Future<void> _deleteEmployee(int id) async {
    final token = await _storage.read(key: 'auth_token');
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/admin/employees/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        _showSnackBar(data['message']);
        _fetchEmployees();
      } else {
        _showSnackBar(data['message'], isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    }
  }

  void _showDeleteConfirmation(UserModel employee) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Warning Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFD32F2F).withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Hapus Karyawan?',
                    style: PoppinsTextStyle.bold.copyWith(
                      fontSize: 24,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Employee Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF5F7FA), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF34495E), Color(0xFF2C3E50)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2C3E50).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              employee.name.isNotEmpty
                                  ? employee.name[0].toUpperCase()
                                  : '?',
                              style: PoppinsTextStyle.bold.copyWith(
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: PoppinsTextStyle.semiBold.copyWith(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nomor Karyawan: ${employee.nik}',
                                style: PoppinsTextStyle.regular.copyWith(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Data karyawan ini akan dihapus secara permanen dan tidak dapat dikembalikan.',
                    textAlign: TextAlign.center,
                    style: PoppinsTextStyle.regular.copyWith(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
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
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteEmployee(employee.id);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: Color(0xFFD32F2F).withOpacity(0.3),
                          ),
                          child: Text(
                            'Ya, Hapus',
                            style: PoppinsTextStyle.semiBold.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Color(0xFFD32F2F) : Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black87,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Data Karyawan',
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Column(
        children: [
          // Enhanced Header Card with Gradient - HANYA KARYAWAN AKTIF
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF34495E), Color(0xFF2C3E50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2C3E50).withOpacity(0.3),
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
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.group_rounded,
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
                        'Total Karyawan Aktif',
                        style: PoppinsTextStyle.medium.copyWith(
                          fontSize: 14,
                          color: Colors.white70,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Aktif',
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Employee List
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2C3E50),
                      ),
                    )
                    : _employees.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _fetchEmployees,
                      color: Color(0xFF2C3E50),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          // Karyawan Aktif
                          if (_activeEmployees.isNotEmpty) ...[
                            ..._activeEmployees.map((employee) => 
                              _buildEmployeeCard(employee)
                            ),
                          ],
                          
                          // Divider dan Header Non-Aktif
                          if (_inactiveEmployees.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInactiveHeader(),
                            const SizedBox(height: 16),
                            ..._inactiveEmployees.map((employee) => 
                              _buildEmployeeCard(employee)
                            ),
                          ],
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF5F7FA), Color(0xFFE8EAF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
            'Karyawan yang ditambahkan akan\nmuncul di sini',
            textAlign: TextAlign.center,
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(UserModel employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar with Gradient
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF34495E), Color(0xFF2C3E50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2C3E50).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
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

            // Employee Info
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(Icons.badge_outlined, employee.nik),
                      _buildInfoChip(Icons.work_outline, employee.jabatan),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status Dropdown with Enhanced Style
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            employee.status == 'aktif'
                                ? [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]
                                : [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            employee.status == 'aktif'
                                ? Color(0xFF4CAF50)
                                : Color(0xFFD32F2F),
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: employee.status,
                        isDense: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color:
                              employee.status == 'aktif'
                                  ? Color(0xFF4CAF50)
                                  : Color(0xFFD32F2F),
                        ),
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 12,
                          color:
                              employee.status == 'aktif'
                                  ? Color(0xFF4CAF50)
                                  : Color(0xFFD32F2F),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'aktif',
                            child: Text('Aktif'),
                          ),
                          DropdownMenuItem(
                            value: 'tidak_aktif',
                            child: Text('Non-Aktif'),
                          ),
                        ],
                        onChanged: (newStatus) {
                          if (newStatus != null)
                            _updateEmployeeStatus(employee.id, newStatus);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Delete Button
            GestureDetector(
              onTap: () => _showDeleteConfirmation(employee),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: PoppinsTextStyle.medium.copyWith(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}