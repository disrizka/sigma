import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_image.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/admin/auth/login/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api';

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getUser();
  }

  Future<void> getUser() async {
    setState(() {
      isLoading = true;
    });

    try {
      final token = await storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
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
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          userData = null;
        });
      }
    } catch (e) {
      print("Error getUser: $e");
      setState(() {
        isLoading = false;
        userData = null;
      });
    }
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Akun Saya',
          style: PoppinsTextStyle.bold.copyWith(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : userData == null
              ? _buildErrorState()
              : RefreshIndicator(
                onRefresh: getUser,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 16),
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                     
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat data',
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan coba lagi',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: getUser,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Muat Ulang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColor.primaryColor, AppColor.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(userData!['name'] ?? userData!['nama'] ?? 'U'),
                style: PoppinsTextStyle.bold.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userData!['name'] ?? userData!['nama'] ?? 'User',
            style: PoppinsTextStyle.bold.copyWith(
              color: Colors.black,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            userData!['jabatan'] ?? userData!['position'] ?? '-',
            style: PoppinsTextStyle.medium.copyWith(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Pribadi',
            style: PoppinsTextStyle.bold.copyWith(
              color: Colors.black,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoItem(
            icon: Icons.person_outline,
            label: 'Nama Lengkap',
            value: userData!['name'] ?? userData!['nama'] ?? '-',
            iconColor: Colors.blue,
          ),
          _buildDivider(),
          _buildInfoItem(
            icon: Icons.badge_outlined,
            label: 'NIK',
            value: userData!['nik'] ?? '-',
            iconColor: Colors.green,
          ),
          _buildDivider(),
          _buildDivider(),
          _buildInfoItem(
            icon: Icons.business_center_outlined,
            label: 'Jenis Pekerjaan',
            value: userData!['jabatan'] ?? userData!['position'] ?? '-',
            iconColor: Colors.purple,
          ),
          _buildDivider(),
          _buildInfoItem(
            icon: Icons.info_outline,
            label: 'Status',
            value: userData!['status'] ?? '-',
            iconColor: Colors.teal,
            isStatus: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: PoppinsTextStyle.regular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                isStatus
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(value).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(value),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        value,
                        style: PoppinsTextStyle.semiBold.copyWith(
                          color: _getStatusColor(value),
                          fontSize: 14,
                        ),
                      ),
                    )
                    : Text(
                      value,
                      style: PoppinsTextStyle.semiBold.copyWith(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade200, thickness: 1, height: 1);
  }

  

  String _getInitials(String name) {
    List<String> names = name.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aktif':
        return Colors.green;
      case 'nonaktif':
        return Colors.red;
      case 'cuti':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
