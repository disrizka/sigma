import 'package:flutter/material.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminTambahKaryawanScreen extends StatefulWidget {
  const AdminTambahKaryawanScreen({super.key});

  @override
  State<AdminTambahKaryawanScreen> createState() =>
      _AdminTambahKaryawanScreenState();
}

class _AdminTambahKaryawanScreenState extends State<AdminTambahKaryawanScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api';

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pekerjaanController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingNIK = true;
  bool _obscurePassword = true;
  String _generatedNIK = '';

  @override
  void initState() {
    super.initState();
    _generateNextNIK();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _passwordController.dispose();
    _pekerjaanController.dispose();
    super.dispose();
  }

  Future<void> _generateNextNIK() async {
    setState(() => _isLoadingNIK = true);

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
        final List<dynamic> employees = json.decode(response.body);

        // Cari NIK terakhir dengan format TWSXXXX
        int maxNumber = 0;
        for (var employee in employees) {
          String nik = employee['nik'] ?? '';
          if (nik.startsWith('TWS')) {
            // Ambil 4 digit terakhir
            String lastFourDigits = nik.substring(3); // Ambil setelah "TWS"
            int number = int.tryParse(lastFourDigits) ?? 0;
            if (number > maxNumber) {
              maxNumber = number;
            }
          }
        }

        // Generate NIK baru (increment dari yang terakhir)
        int nextNumber = maxNumber + 1;
        String nikNumber = nextNumber.toString().padLeft(4, '0');

        setState(() {
          _generatedNIK = 'TWS$nikNumber';
          _isLoadingNIK = false;
        });
      } else {
        // Jika gagal, mulai dari 0001
        setState(() {
          _generatedNIK = 'TWS0001';
          _isLoadingNIK = false;
        });
      }
    } catch (e) {
      // Jika error, mulai dari 0001
      setState(() {
        _generatedNIK = 'TWS0001';
        _isLoadingNIK = false;
      });
    }
  }

  Future<void> _addKaryawan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_generatedNIK.isEmpty) {
      _showError('Nomor Karyawan belum di-generate. Silakan coba lagi.');
      return;
    }

    setState(() => _isLoading = true);

    final token = await _storage.read(key: 'auth_token');
    final url = Uri.parse('$_baseUrl/admin/create-employee');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'name': _namaController.text.trim(),
          'nik': _generatedNIK,
          'password': _passwordController.text,
          'jabatan': _pekerjaanController.text.trim(),
          'status': 'aktif',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        if (mounted) {
          _showSuccess('Karyawan berhasil ditambahkan!');
          Navigator.pop(context, true);
        }
      } else {
        String errorMessage = data['message'] ?? 'Gagal menambah karyawan.';
        if (data['errors'] != null) {
          errorMessage = (data['errors'] as Map).values.first[0];
        }
        _showError(errorMessage);
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        title: Text(
          'Tambah Karyawan',
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoadingNIK
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Mempersiapkan Nomor Karyawan...',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColor.primaryColor,
                              AppColor.primaryColor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColor.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                color: AppColor.primaryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tambah Karyawan Baru',
                                    style: PoppinsTextStyle.bold.copyWith(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lengkapi semua informasi dengan benar',
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

                      const SizedBox(height: 32),

                      // NIK Display Card (Read-only, Auto-generated)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade200,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.badge_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Nomor Karyawan',
                                        style: PoppinsTextStyle.semiBold
                                            .copyWith(
                                              fontSize: 12,
                                              color: Colors.green.shade900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Otomatis dibuat oleh sistem',
                                        style: PoppinsTextStyle.regular
                                            .copyWith(
                                              fontSize: 10,
                                              color: Colors.green.shade700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _generatedNIK,
                                    style: PoppinsTextStyle.bold.copyWith(
                                      fontSize: 18,
                                      color: Colors.green.shade900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'AUTO',
                                      style: PoppinsTextStyle.bold.copyWith(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Form Fields
                      _buildTextField(
                        controller: _namaController,
                        label: 'Nama Lengkap',
                        hint: 'Masukkan nama lengkap',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Masukkan password',
                        icon: Icons.lock_rounded,
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password tidak boleh kosong';
                          }
                          if (value.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _pekerjaanController,
                        label: 'Jenis Pekerjaan',
                        hint: 'Masukkan jenis pekerjaan',
                        icon: Icons.work_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jenis pekerjaan tidak boleh kosong';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Info Box
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
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Nomor Karyawan akan digunakan untuk login karyawan bersama dengan password',
                                style: PoppinsTextStyle.regular.copyWith(
                                  fontSize: 11,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addKaryawan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: AppColor.primaryColor.withOpacity(0.3),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Simpan Karyawan',
                                        style: PoppinsTextStyle.bold.copyWith(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: PoppinsTextStyle.semiBold.copyWith(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PoppinsTextStyle.semiBold.copyWith(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: PoppinsTextStyle.regular.copyWith(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(icon, color: AppColor.primaryColor, size: 22),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
