import 'package:flutter/material.dart';
import 'package:sigma/admin/auth/login/login_screen.dart';
import 'package:sigma/karyawan/main/bottom_navigation_bar.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserModel {
  final String name;
  final String nik;
  final String jabatan;

  UserModel({required this.name, required this.nik, required this.jabatan});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? 'Nama Pengguna',
      nik: json['nik'] ?? 'N/A',
      jabatan: json['jabatan'] ?? 'N/A',
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://10.0.2.2:8000/api';

  String name = "Memuat...";
  String nik = "...";
  String position = "...";

  TextEditingController oldPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  bool obscureOldPassword = true;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  bool _isDialogLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // --- FUNGSI-FUNGSI LOGIKA & API ---

  Future<void> _loadUserData() async {
    final token = await _storage.read(key: 'auth_token');
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final userData = UserModel.fromJson(json.decode(response.body));
        if (mounted) {
          setState(() {
            name = userData.name;
            nik = userData.nik;
            position = userData.jabatan;
          });
        }
      } else {
        _showElegantSnackBar('Gagal memuat data pengguna', isError: true);
      }
    } catch (e) {
      _showElegantSnackBar('Terjadi kesalahan koneksi', isError: true);
    }
  }

  Future<void> _handleChangePassword(StateSetter setDialogState) async {
    final navigator = Navigator.of(context);

    if (oldPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showElegantSnackBar("Semua field harus diisi", isError: true);
      return;
    }
    if (newPasswordController.text != confirmPasswordController.text) {
      _showElegantSnackBar("Password baru tidak cocok", isError: true);
      return;
    }
    if (newPasswordController.text.length < 6) {
      _showElegantSnackBar("Password minimal 6 karakter", isError: true);
      return;
    }

    setDialogState(() => _isDialogLoading = true);

    final token = await _storage.read(key: 'auth_token');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          '_method': 'PUT',
          'current_password': oldPasswordController.text,
          'new_password': newPasswordController.text,
          'new_password_confirmation': confirmPasswordController.text,
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        navigator.pop();
        _showElegantSnackBar("Password berhasil diubah");
      } else {
        _showElegantSnackBar("Gagal: ${responseData['message']}", isError: true);
      }
    } catch (e) {
      _showElegantSnackBar('Terjadi kesalahan koneksi', isError: true);
    } finally {
      if(mounted) setDialogState(() => _isDialogLoading = false);
    }
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: _buildDialogTitle(icon: Icons.logout, text: 'Konfirmasi Keluar', color: Colors.red),
        content: Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
          style: PoppinsTextStyle.regular.copyWith(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: PoppinsTextStyle.medium.copyWith(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Ya, Keluar', style: PoppinsTextStyle.semiBold),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final token = await _storage.read(key: 'auth_token');
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } finally {
      await _storage.delete(key: 'auth_token');
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showElegantSnackBar(String message, {bool isError = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: PoppinsTextStyle.medium.copyWith(color: Colors.white, fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showChangePasswordDialog() {
    oldPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    obscureOldPassword = true;
    obscureNewPassword = true;
    obscureConfirmPassword = true;
    _isDialogLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: _buildDialogTitle(icon: Icons.lock_reset, text: 'Ganti Password', color: Colors.blue),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPasswordTextField(
                  controller: oldPasswordController,
                  labelText: 'Password Lama',
                  isObscure: obscureOldPassword,
                  onToggleVisibility: () => setDialogState(() => obscureOldPassword = !obscureOldPassword),
                ),
                const SizedBox(height: 16),
                _buildPasswordTextField(
                  controller: newPasswordController,
                  labelText: 'Password Baru',
                  isObscure: obscureNewPassword,
                  onToggleVisibility: () => setDialogState(() => obscureNewPassword = !obscureNewPassword),
                ),
                const SizedBox(height: 16),
                _buildPasswordTextField(
                  controller: confirmPasswordController,
                  labelText: 'Konfirmasi Password Baru',
                  isObscure: obscureConfirmPassword,
                  onToggleVisibility: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: PoppinsTextStyle.medium.copyWith(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: _isDialogLoading ? null : () => _handleChangePassword(setDialogState),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isDialogLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Simpan', style: PoppinsTextStyle.semiBold),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BottomBar())),
        ),
        title: Text(
          'Pengaturan',
          style: PoppinsTextStyle.bold.copyWith(color: Colors.black, fontSize: 24),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColor.primaryColor, AppColor.primaryColor.withOpacity(0.7)]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColor.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: PoppinsTextStyle.bold.copyWith(fontSize: 28, color: AppColor.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: PoppinsTextStyle.bold.copyWith(fontSize: 18, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.badge, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  'NIK: $nik',
                                  style: PoppinsTextStyle.medium.copyWith(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _showChangePasswordDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade400]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.blue.shade300.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_reset, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Ganti Password',
                            style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _buildSection(
              "Pengaturan Akun",
              Icons.settings,
              Colors.blue.shade600,
              [
                _buildSettingItem(
                  icon: Icons.person,
                  title: "Akun Saya",
                  subtitle: "Lihat detail akun Anda",
                  backgroundColor: Colors.blue.shade500,
                  onTap: () => _showElegantSnackBar("Fitur Akun Saya dalam pengembangan"),
                ),
                _buildSettingItem(
                  icon: Icons.lock_outline,
                  title: "Privasi & Keamanan",
                  subtitle: "Kelola keamanan akun Anda",
                  backgroundColor: Colors.purple.shade500,
                  onTap: () => _showElegantSnackBar("Fitur Privasi dalam pengembangan"),
                ),
                _buildSettingItem(
                  icon: Icons.help_center,
                  title: "Bantuan",
                  subtitle: "FAQ dan panduan penggunaan",
                  backgroundColor: Colors.green.shade500,
                  onTap: () => _showElegantSnackBar("Fitur Bantuan dalam pengembangan"),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red.shade600, Colors.red.shade400]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.red.shade300.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _signOut(),
                icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                label: Text("Keluar dari Akun", style: PoppinsTextStyle.bold.copyWith(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData titleIcon, Color titleColor, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: titleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(titleIcon, color: titleColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: PoppinsTextStyle.bold.copyWith(fontSize: 16, color: Colors.black87)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: items),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool showDivider = true,
    String? subtitle,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [backgroundColor, backgroundColor.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: backgroundColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: Colors.black87)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: PoppinsTextStyle.regular.copyWith(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade300, size: 16),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(height: 16, thickness: 0.5, color: Colors.grey.shade200),
          ),
      ],
    );
  }

  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String labelText,
    required bool isObscure,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: PoppinsTextStyle.regular.copyWith(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColor.primaryColor, width: 2)),
      ),
    );
  }
  
  Row _buildDialogTitle({required IconData icon, required String text, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon ,size: 24),
        ),
        const SizedBox(width: 12),
        Text(text, style: PoppinsTextStyle.semiBold.copyWith(fontSize: 16)),
      ],
    );
  }
}