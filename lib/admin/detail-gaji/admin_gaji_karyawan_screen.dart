import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as _storage;
import 'package:intl/intl.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

class AdminSlipGajiListScreen extends StatefulWidget {
  const AdminSlipGajiListScreen({super.key});

  @override
  State<AdminSlipGajiListScreen> createState() =>
      _AdminSlipGajiListScreenState();
}

class _AdminSlipGajiListScreenState extends State<AdminSlipGajiListScreen> {
  bool _isLoading = true;
  List<KaryawanSlipGaji> _slipGajiList = [];
  List<KaryawanSlipGaji> _filteredList = [];
  String _selectedBulan = '';
  final TextEditingController _searchController = TextEditingController();
  final String _baseUrl = '$baseUrl/api/admin';

  List<String> _bulanOptions = [];
  String? _token;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _initializeBulanOptions();
      _loadToken();
    });
  }

  void _initializeBulanOptions() {
    print('📅 Initializing bulan options...');
    DateTime now = DateTime.now();
    List<String> months = [];

    for (int i = 0; i < 6; i++) {
      DateTime date = DateTime(now.year, now.month - i, 1);
      String monthYear = DateFormat('MMMM yyyy', 'id_ID').format(date);
      months.add(monthYear);
      print('   - Bulan ditambahkan: $monthYear');
    }

    setState(() {
      _bulanOptions = months;
      _selectedBulan = months.isNotEmpty ? months[0] : '';
    });

    print('✅ Bulan options berhasil: $_bulanOptions');
    print('✅ Selected bulan: $_selectedBulan');
  }

  final _storage = const FlutterSecureStorage();

  Future<void> _loadToken() async {
    print('🔑 Loading token...');
    try {
      final token = await _storage.read(key: 'auth_token');

      print(
        '🔑 Token ditemukan: ${token != null ? "YES (${token.substring(0, 20)}...)" : "NO"}',
      );

      if (token != null && token.isNotEmpty) {
        print('✅ Token valid, memanggil _loadSlipGaji()');
        await _loadSlipGaji(token);
      } else {
        print('❌ Token kosong atau null');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('💥 Error loading token: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading token: $e');
    }
  }

  Future<void> _loadSlipGaji([String? tokenParam]) async {
    final token = tokenParam ?? await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DateTime selectedDate = DateFormat(
        'MMMM yyyy',
        'id_ID',
      ).parse(_selectedBulan);
      int month = selectedDate.month;
      int year = selectedDate.year;

      print('🔍 Loading slip gaji untuk: $month/$year');

      final employeesResponse = await http
          .get(
            Uri.parse('$_baseUrl/employees'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('📋 Employees Response Status: ${employeesResponse.statusCode}');

      if (employeesResponse.statusCode == 200) {
        List<dynamic> employees = json.decode(employeesResponse.body);
        print('👥 Jumlah karyawan: ${employees.length}');

        List<KaryawanSlipGaji> slipGajiList = [];

        for (var employee in employees) {
          try {
            print(
              '🔄 Memproses karyawan: ${employee['name']} (ID: ${employee['id']})',
            );

            final payslipUrl =
                '$_baseUrl/payslip-live/${employee['id']}/$year/$month';
            print('🌐 Request URL: $payslipUrl');

            final payslipResponse = await http
                .get(
                  Uri.parse(payslipUrl),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                  },
                )
                .timeout(const Duration(seconds: 10));

            print(
              '📊 Payslip Response Status untuk ${employee['name']}: ${payslipResponse.statusCode}',
            );

            if (payslipResponse.statusCode == 200) {
              var responseData = json.decode(payslipResponse.body);
              print('✅ Response Data: $responseData');

              var payslipData = responseData['data'];
              print('💰 Payslip Data: $payslipData');

              slipGajiList.add(
                KaryawanSlipGaji(
                  id: employee['id'] ?? 0,
                  nik: employee['nik']?.toString() ?? '',
                  namaKaryawan: employee['name']?.toString() ?? 'Unknown',
                  jabatan: employee['jabatan']?.toString() ?? '',
                  gajiPokok: _parseToInt(payslipData['total_basic_salary']),
                  tunjangan: _parseToInt(payslipData['total_allowance']),
                  potongan: _parseToInt(payslipData['total_deduction']),
                  pajak: _parseToInt(payslipData['tax']),
                  foto: null,
                ),
              );

              print(
                '✔️ Berhasil menambahkan slip gaji untuk ${employee['name']}',
              );
            } else {
              print('❌ Error Payslip untuk ${employee['name']}:');
              print('   Status: ${payslipResponse.statusCode}');
              print('   Body: ${payslipResponse.body}');
            }
          } catch (e) {
            print('⚠️ Skip employee ${employee['name']}: $e');
            print('   Error detail: ${e.toString()}');
          }
        }

        print('📦 Total slip gaji berhasil dimuat: ${slipGajiList.length}');

        // 🏆 SORTING BERDASARKAN GAJI BERSIH (TERBESAR KE TERKECIL)
        slipGajiList.sort((a, b) => b.gajiBersih.compareTo(a.gajiBersih));
        
        // Debug: Print 3 teratas
        print('🏆 TOP 3 GAJI:');
        for (int i = 0; i < (slipGajiList.length > 3 ? 3 : slipGajiList.length); i++) {
          print('   ${i + 1}. ${slipGajiList[i].namaKaryawan} - Rp ${slipGajiList[i].gajiBersih}');
        }

        setState(() {
          _slipGajiList = slipGajiList;
          _filteredList = slipGajiList;
          _isLoading = false;
        });
      } else if (employeesResponse.statusCode == 401) {
        print('🔐 Token tidak valid - Status: ${employeesResponse.statusCode}');
        setState(() {
          _isLoading = false;
        });
        _showError('Token tidak valid. Silakan login kembali.');
      } else {
        print('❌ Error getting employees:');
        print('   Status: ${employeesResponse.statusCode}');
        print('   Body: ${employeesResponse.body}');
        throw Exception(
          'Gagal memuat data karyawan: ${employeesResponse.statusCode}',
        );
      }
    } catch (e) {
      print('💥 Error di _loadSlipGaji: $e');
      print('   Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
      _showError('Error: $e');
    }
  }

  // 🏆 FUNGSI UNTUK MENDAPATKAN RANKING
  int _getRanking(KaryawanSlipGaji item) {
    int index = _filteredList.indexOf(item);
    return index + 1;
  }

  // 🏆 FUNGSI UNTUK MENDAPATKAN WARNA RANKING
  Color _getRankingColor(int ranking) {
    switch (ranking) {
      case 1:
        return Color(0xFFFFD700); // Gold
      case 2:
        return Color(0xFFC0C0C0); // Silver
      case 3:
        return Color(0xFFCD7F32); // Bronze
      default:
        return Colors.transparent;
    }
  }

  // 🏆 FUNGSI UNTUK MENDAPATKAN ICON RANKING
  IconData _getRankingIcon(int ranking) {
    switch (ranking) {
      case 1:
        return Icons.emoji_events; // Trophy
      case 2:
        return Icons.emoji_events;
      case 3:
        return Icons.emoji_events;
      default:
        return Icons.stars;
    }
  }

  Future<void> _showDetailDialog(KaryawanSlipGaji item) async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      _showError('Token tidak ditemukan. Silakan login kembali.');
      return;
    }

    DateTime selectedDate = DateFormat(
      'MMMM yyyy',
      'id_ID',
    ).parse(_selectedBulan);
    int month = selectedDate.month;
    int year = selectedDate.year;

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/payslip-live/${item.id}/$year/$month'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        var payslipData = responseData['data'];

        if (!mounted) return;

        int ranking = _getRanking(item);

        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
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
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // 🏆 RANKING BADGE (di atas avatar)
                        if (ranking <= 3)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getRankingColor(ranking),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _getRankingColor(ranking).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRankingIcon(ranking),
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ranking #$ranking',
                                  style: PoppinsTextStyle.bold.copyWith(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Text(
                            item.namaKaryawan.isNotEmpty
                                ? item.namaKaryawan
                                    .substring(0, 1)
                                    .toUpperCase()
                                : '?',
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 28,
                              color: AppColor.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.namaKaryawan,
                          style: PoppinsTextStyle.bold.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NIK: ${item.nik} • ${item.jabatan}',
                          style: PoppinsTextStyle.regular.copyWith(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Gaji Bersih',
                                style: PoppinsTextStyle.regular.copyWith(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(item.gajiBersih),
                                style: PoppinsTextStyle.bold.copyWith(
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Detail Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailSection(
                            'Pendapatan',
                            Icons.add_circle_outline,
                            Colors.green,
                            [
                              DetailRow('Gaji Pokok', item.gajiPokok),
                              DetailRow('Total Tunjangan', item.tunjangan),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailSection(
                            'Potongan',
                            Icons.remove_circle_outline,
                            Colors.red,
                            [
                              DetailRow('Potongan Harian', item.potongan),
                              if (item.pajak > 0)
                                DetailRow('Pajak Bulanan', item.pajak),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Periode: $_selectedBulan\n${item.pajak > 0 ? "Pajak sudah dipotong (akhir bulan)" : "Pajak belum dipotong (belum akhir bulan)"}',
                                    style: PoppinsTextStyle.regular.copyWith(
                                      fontSize: 11,
                                      color: Colors.blue[900],
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
                  // Footer Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tutup',
                          style: PoppinsTextStyle.semiBold.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        _showError('Gagal memuat detail: Status ${response.statusCode}');
      }
    } catch (e) {
      _showError('Gagal memuat detail: $e');
    }
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = _slipGajiList;
      } else {
        _filteredList = _slipGajiList.where((item) {
          return item.namaKaryawan.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              item.nik.toLowerCase().contains(query.toLowerCase()) ||
              item.jabatan.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      
      // 🏆 PASTIKAN TETAP SORTED SETELAH FILTER
      _filteredList.sort((a, b) => b.gajiBersih.compareTo(a.gajiBersih));
      
      // Debug filtered list
      print('🔍 Filtered list count: ${_filteredList.length}');
      if (_filteredList.isNotEmpty) {
        print('   Top 1: ${_filteredList[0].namaKaryawan} - Rp ${_filteredList[0].gajiBersih}');
      }
    });
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  int _getTotalGajiBersih() {
    return _filteredList.fold(0, (sum, item) => sum + item.gajiBersih);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    IconData icon,
    Color color,
    List<DetailRow> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: rows.map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      _formatCurrency(row.amount),
                      style: PoppinsTextStyle.semiBold.copyWith(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Build widget dipanggil, _isLoading: $_isLoading');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        toolbarHeight: 100,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            print('🔙 Back button pressed');
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Slip Gaji Karyawan',
          style: PoppinsTextStyle.bold.copyWith(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat data...'),
                      ],
                    ),
                  )
                : _filteredList.isEmpty
                    ? _buildEmptyState()
                    : _buildSlipGajiList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColor.primaryColor),
            ),
            child: DropdownButton<String>(
              value: _selectedBulan.isNotEmpty ? _selectedBulan : null,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: AppColor.primaryColor),
              style: PoppinsTextStyle.semiBold.copyWith(
                fontSize: 14,
                color: AppColor.primaryColor,
              ),
              items: _bulanOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedBulan = newValue;
                  });
                  _loadSlipGaji();
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _filterSearch,
            decoration: InputDecoration(
              hintText: 'Cari nama, NIK, atau jabatan...',
              hintStyle: PoppinsTextStyle.regular.copyWith(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[400]),
                      onPressed: () {
                        _searchController.clear();
                        _filterSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
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
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Gaji Bersih',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(_getTotalGajiBersih()),
                      style: PoppinsTextStyle.bold.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        '${_filteredList.length} Karyawan',
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlipGajiList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredList.length,
      itemBuilder: (context, index) {
        final item = _filteredList[index];
        return _buildSlipGajiCard(item, index + 1);
      },
    );
  }

  Widget _buildSlipGajiCard(KaryawanSlipGaji item, int ranking) {
    bool isTopThree = ranking <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTopThree ? _getRankingColor(ranking) : Colors.grey[200]!,
          width: isTopThree ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isTopThree
                ? _getRankingColor(ranking).withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: isTopThree ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailDialog(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // 🏆 RANKING BADGE (kiri avatar)
                    if (isTopThree)
                      Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _getRankingColor(ranking),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getRankingColor(ranking).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '#$ranking',
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColor.primaryColor.withOpacity(0.1),
                      child: Text(
                        item.namaKaryawan.isNotEmpty
                            ? item.namaKaryawan.substring(0, 1).toUpperCase()
                            : '?',
                        style: PoppinsTextStyle.bold.copyWith(
                          fontSize: 20,
                          color: AppColor.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaKaryawan,
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIK: ${item.nik}',
                            style: PoppinsTextStyle.regular.copyWith(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.jabatan,
                              style: PoppinsTextStyle.medium.copyWith(
                                fontSize: 10,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoColumn(
                        'Gaji Pokok',
                        _formatCurrency(item.gajiPokok),
                        Colors.green,
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildInfoColumn(
                        'Tunjangan',
                        _formatCurrency(item.tunjangan),
                        Colors.blue,
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildInfoColumn(
                        'Potongan',
                        _formatCurrency(item.totalPotongan),
                        Colors.red,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isTopThree
                        ? _getRankingColor(ranking)
                        : AppColor.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isTopThree) ...[
                            Icon(
                              _getRankingIcon(ranking),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Gaji Bersih',
                            style: PoppinsTextStyle.semiBold.copyWith(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCurrency(item.gajiBersih),
                        style: PoppinsTextStyle.bold.copyWith(
                          fontSize: 16,
                          color: Colors.white,
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

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 11,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Belum ada slip gaji',
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedBulan.isNotEmpty
                ? 'Slip gaji untuk $_selectedBulan\nbelum tersedia'
                : 'Pilih bulan untuk melihat slip gaji',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 13,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class KaryawanSlipGaji {
  final int id;
  final String nik;
  final String namaKaryawan;
  final String jabatan;
  final int gajiPokok;
  final int tunjangan;
  final int potongan;
  final int pajak;
  final String? foto;

  KaryawanSlipGaji({
    required this.id,
    required this.nik,
    required this.namaKaryawan,
    required this.jabatan,
    required this.gajiPokok,
    required this.tunjangan,
    required this.potongan,
    required this.pajak,
    this.foto,
  });

  int get totalPotongan => potongan + pajak;
  int get gajiBersih => gajiPokok + tunjangan - totalPotongan;
}

class DetailRow {
  final String label;
  final int amount;

  DetailRow(this.label, this.amount);
}