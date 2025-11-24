import 'package:flutter/material.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SlipGajiScreen extends StatefulWidget {
  const SlipGajiScreen({super.key});

  @override
  State<SlipGajiScreen> createState() => _SlipGajiScreenState();
}

class _SlipGajiScreenState extends State<SlipGajiScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api/karyawan';

  String selectedMonth = DateFormat(
    'MMMM yyyy',
    'id_ID',
  ).format(DateTime.now());
  int selectedYear = DateTime.now().year;
  int selectedMonthNum = DateTime.now().month;

  bool isLoading = false;
  Map<String, dynamic>? slipGajiData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSlipGaji();
  }

  Future<void> _loadSlipGaji() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      slipGajiData = null; // Reset data sebelumnya
    });

    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login kembali.';
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
        '$_baseUrl/payslip-live/$selectedYear/$selectedMonthNum',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          slipGajiData = data['data'];
          isLoading = false;
          errorMessage = null;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          slipGajiData = null;
          errorMessage = 'Slip gaji untuk $selectedMonth belum tersedia.';
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = 'Sesi Anda telah berakhir. Silakan login kembali.';
          isLoading = false;
        });
      } else {
        try {
          final errorData = json.decode(response.body);
          setState(() {
            errorMessage = errorData['message'] ?? 'Gagal memuat slip gaji';
            isLoading = false;
          });
        } catch (e) {
          setState(() {
            errorMessage = 'Gagal memuat slip gaji: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Parse data dari backend
  List<Map<String, dynamic>> get riwayatHarian {
    if (slipGajiData == null || slipGajiData!['daily_details'] == null) {
      return [];
    }

    return (slipGajiData!['daily_details'] as List).map((item) {
      return {
        'tanggal': DateFormat(
          'dd MMM yyyy',
          'id_ID',
        ).format(DateTime.parse(item['date'])),
        'status': _mapStatus(item['status']),
        'jamMasuk': item['check_in'] ?? '-',
        'jamKeluar': item['check_out'] ?? '-',
        'gajiPokok': item['basic_salary'] ?? 0,
        'tunjangan': item['allowance'] ?? 0,
        'potongan': item['deduction'] ?? 0,
      };
    }).toList();
  }

  String _mapStatus(String backendStatus) {
    // Mapping status dari backend ke tampilan
    switch (backendStatus.toLowerCase()) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat_masuk':
        return 'Terlambat Masuk';
      case 'pulang_duluan':
        return 'Pulang Duluan';
      case 'cuti':
        return 'Cuti';
      case 'izin':
        return 'Izin';
      case 'alpha':
        return 'Alpha';
      default:
        return backendStatus;
    }
  }

  int get totalGajiPokok => slipGajiData?['total_basic_salary'] ?? 0;
  int get totalTunjangan => slipGajiData?['total_allowance'] ?? 0;
  int get totalPotongan => slipGajiData?['total_deduction'] ?? 0;
  int get pajakBulanan => slipGajiData?['tax'] ?? 100000;
  int get totalDiterima => slipGajiData?['net_salary'] ?? 0;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hadir':
        return Colors.green;
      case 'Terlambat Masuk':
        return Colors.orange;
      case 'Pulang Duluan':
        return Colors.deepOrange;
      case 'Cuti':
        return Colors.blue;
      case 'Izin':
        return Colors.purple;
      case 'Alpha':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Hadir':
        return Icons.check_circle;
      case 'Terlambat Masuk':
        return Icons.access_time;
      case 'Pulang Duluan':
        return Icons.exit_to_app;
      case 'Cuti':
        return Icons.beach_access;
      case 'Izin':
        return Icons.assignment;
      case 'Alpha':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getKeterangan(Map<String, dynamic> data) {
    switch (data['status']) {
      case 'Hadir':
        return 'Hadir tepat waktu';
      case 'Terlambat Masuk':
        return 'Terlambat masuk kerja';
      case 'Pulang Duluan':
        return 'Pulang lebih awal';
      case 'Cuti':
        return 'Cuti disetujui';
      case 'Izin':
        return 'Izin disetujui';
      case 'Alpha':
        return 'Tidak hadir tanpa keterangan';
      default:
        return '';
    }
  }

  Future<void> _pilihBulan() async {
    final List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final List<int> years =
        List.generate(
          DateTime.now().year - 2020 + 1,
          (index) => 2020 + index,
        ).reversed.toList();

    int tempMonth = selectedMonthNum;
    int tempYear = selectedYear;

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 350,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Periode',
                        style: PoppinsTextStyle.bold.copyWith(fontSize: 18),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Year Selector
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<int>(
                      value: tempYear,
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: AppColor.primaryColor,
                      ),
                      style: PoppinsTextStyle.semiBold.copyWith(
                        fontSize: 16,
                        color: AppColor.primaryColor,
                      ),
                      items:
                          years.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            tempYear = value;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 20),

                  // Month Grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthNum = index + 1;
                        final isSelected = tempMonth == monthNum;
                        final isFuture =
                            tempYear == DateTime.now().year &&
                            monthNum > DateTime.now().month;

                        return InkWell(
                          onTap:
                              isFuture
                                  ? null
                                  : () {
                                    setModalState(() {
                                      tempMonth = monthNum;
                                    });
                                  },
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColor.primaryColor
                                      : isFuture
                                      ? Colors.grey[200]
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? AppColor.primaryColor
                                        : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                months[index].substring(0, 3),
                                style: PoppinsTextStyle.medium.copyWith(
                                  fontSize: 13,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : isFuture
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),

                  // OK Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'month': tempMonth,
                          'year': tempYear,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Pilih',
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedYear = result['year']!;
        selectedMonthNum = result['month']!;
        final picked = DateTime(selectedYear, selectedMonthNum);
        try {
          selectedMonth = DateFormat('MMMM yyyy', 'id_ID').format(picked);
        } catch (e) {
          selectedMonth = DateFormat('MMMM yyyy').format(picked);
        }
      });
      _loadSlipGaji();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColor.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColor.backgroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Slip Gaji',
          style: PoppinsTextStyle.bold.copyWith(
            fontSize: 18,
            color: AppColor.backgroundColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColor.backgroundColor),
            onPressed: _loadSlipGaji,
          ),
        ],
      ),

      // Ganti bagian body Scaffold dengan yang ini:
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColor.primaryColor),
              )
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: PoppinsTextStyle.medium.copyWith(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Silakan pilih bulan lain',
                      textAlign: TextAlign.center,
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pilihBulan,
                          icon: Icon(Icons.calendar_month, size: 20),
                          label: Text('Pilih Bulan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColor.primaryColor,
                            side: BorderSide(color: AppColor.primaryColor),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _loadSlipGaji,
                          icon: Icon(Icons.refresh, size: 20),
                          label: Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Header dengan ringkasan gaji
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColor.primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      child: Column(
                        children: [
                          // Pemilihan bulan dengan instruksi lebih jelas
                          GestureDetector(
                            onTap: _pilihBulan,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_month,
                                    color: AppColor.backgroundColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedMonth,
                                    style: PoppinsTextStyle.semiBold.copyWith(
                                      fontSize: 14,
                                      color: AppColor.backgroundColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColor.backgroundColor,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ketuk untuk mengubah periode',
                            style: PoppinsTextStyle.regular.copyWith(
                              fontSize: 11,
                              color: AppColor.backgroundColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Total gaji diterima
                          Text(
                            'Total Gaji Diterima',
                            style: PoppinsTextStyle.regular.copyWith(
                              fontSize: 14,
                              color: AppColor.backgroundColor.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rp ${NumberFormat('#,###', 'id_ID').format(totalDiterima)}',
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 32,
                              color: AppColor.backgroundColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Ringkasan Pendapatan & Potongan
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ringkasan Bulanan',
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Card Pendapatan
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.green[200]!,
                                width: 1,
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
                                        Icons.trending_up,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Pendapatan',
                                      style: PoppinsTextStyle.semiBold.copyWith(
                                        fontSize: 14,
                                        color: Colors.green[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  'Gaji Pokok',
                                  totalGajiPokok,
                                  Colors.green[700]!,
                                ),
                                _buildDetailRow(
                                  'Tunjangan Makan & Transport',
                                  totalTunjangan,
                                  Colors.green[700]!,
                                ),
                                const Divider(height: 20),
                                _buildDetailRow(
                                  'Total Pendapatan',
                                  totalGajiPokok + totalTunjangan,
                                  Colors.green[900]!,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Card Potongan
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.red[200]!,
                                width: 1,
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
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.trending_down,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Potongan',
                                      style: PoppinsTextStyle.semiBold.copyWith(
                                        fontSize: 14,
                                        color: Colors.red[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  'Potongan Keterlambatan',
                                  totalPotongan,
                                  Colors.red[700]!,
                                ),
                                _buildDetailRow(
                                  'Pajak Bulanan',
                                  pajakBulanan,
                                  Colors.red[700]!,
                                ),
                                const Divider(height: 20),
                                _buildDetailRow(
                                  'Total Potongan',
                                  totalPotongan + pajakBulanan,
                                  Colors.red[900]!,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Keterangan Aturan Gaji
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.blue[200]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blue[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Keterangan Aturan Gaji',
                                      style: PoppinsTextStyle.semiBold.copyWith(
                                        fontSize: 13,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildKeteranganItem(
                                  '• Jam kerja: 07:30 - 17:00',
                                ),
                                _buildKeteranganItem(
                                  '• Gaji pokok Rp 50.000/hari (absen masuk & keluar tepat waktu)',
                                ),
                                _buildKeteranganItem(
                                  '• Tunjangan Rp 25.000/hari (jika hadir)',
                                ),
                                _buildKeteranganItem(
                                  '• Potongan Rp 25.000 jika terlambat masuk',
                                ),
                                _buildKeteranganItem(
                                  '• Potongan Rp 25.000 jika pulang lebih awal',
                                ),
                                _buildKeteranganItem(
                                  '• Cuti disetujui: dapat gaji pokok, tidak dapat tunjangan',
                                ),
                                _buildKeteranganItem(
                                  '• Izin disetujui: tidak dapat gaji pokok dan tunjangan',
                                ),
                                _buildKeteranganItem(
                                  '• Izin/Cuti ditolak sebelum jam 07:30: status Pending',
                                ),
                                _buildKeteranganItem(
                                  '• Izin/Cuti ditolak setelah jam 17:00: status Alpha',
                                ),
                                _buildKeteranganItem(
                                  '• Alpha: tidak dapat gaji pokok dan tunjangan',
                                ),
                                _buildKeteranganItem(
                                  '• Pajak bulanan: Rp 100.000',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Riwayat Harian
                          Text(
                            'Riwayat Kehadiran Harian',
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (riwayatHarian.isEmpty)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Riwayat Kehadiran Kosong',
                                      style: PoppinsTextStyle.semiBold.copyWith(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Belum ada data kehadiran untuk\n$selectedMonth',
                                      textAlign: TextAlign.center,
                                      style: PoppinsTextStyle.regular.copyWith(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...riwayatHarian
                                .map((data) => _buildRiwayatCard(data))
                                .toList(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildDetailRow(
    String label,
    int amount,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isBold
                    ? PoppinsTextStyle.semiBold
                    : PoppinsTextStyle.regular)
                .copyWith(fontSize: 12, color: color),
          ),
          Text(
            'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}',
            style: (isBold
                    ? PoppinsTextStyle.semiBold
                    : PoppinsTextStyle.regular)
                .copyWith(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildKeteranganItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: PoppinsTextStyle.regular.copyWith(
          fontSize: 11,
          color: Colors.blue[900],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> data) {
    final statusColor = _getStatusColor(data['status']);
    final statusIcon = _getStatusIcon(data['status']);
    final totalHari =
        (data['gajiPokok'] as int) +
        (data['tunjangan'] as int) -
        (data['potongan'] as int);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tanggal dan status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    data['tanggal'],
                    style: PoppinsTextStyle.semiBold.copyWith(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      data['status'],
                      style: PoppinsTextStyle.semiBold.copyWith(
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jam masuk dan keluar
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.login, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Masuk: ${data['jamMasuk']}',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Keluar: ${data['jamKeluar']}',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail gaji
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gaji Pokok',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Rp ${NumberFormat('#,###', 'id_ID').format(data['gajiPokok'])}',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 11,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tunjangan',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Rp ${NumberFormat('#,###', 'id_ID').format(data['tunjangan'])}',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 11,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                if ((data['potongan'] as int) > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Potongan',
                        style: PoppinsTextStyle.regular.copyWith(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '- Rp ${NumberFormat('#,###', 'id_ID').format(data['potongan'])}',
                        style: PoppinsTextStyle.medium.copyWith(
                          fontSize: 11,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Hari Ini',
                      style: PoppinsTextStyle.semiBold.copyWith(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Rp ${NumberFormat('#,###', 'id_ID').format(totalHari)}',
                      style: PoppinsTextStyle.bold.copyWith(
                        fontSize: 12,
                        color:
                            totalHari > 0
                                ? Colors.green[700]
                                : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Keterangan
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getKeterangan(data),
                    style: PoppinsTextStyle.regular.copyWith(
                      fontSize: 10,
                      color: statusColor.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
