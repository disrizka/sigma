import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'package:sigma/api/api.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sigma/utils/app_image.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryItem {
  final String itemType;
  final DateTime createdAt;
  final DateTime? checkInTime, checkOutTime;
  final String? checkInLocation, checkOutLocation;
  final String? leaveType, reason, status, fileProof;
  final String? statusCheckIn, statusCheckOut;
  final DateTime? startDate, endDate;

  HistoryItem({
    required this.itemType,
    required this.createdAt,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.leaveType,
    this.reason,
    this.status,
    this.fileProof,
    this.statusCheckIn,
    this.statusCheckOut,
    this.startDate,
    this.endDate,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    bool isAttendance = json.containsKey('date');
    return HistoryItem(
      itemType: isAttendance ? 'attendance' : 'leave_request',
      createdAt: DateTime.parse(
        isAttendance ? json['date'] : json['start_date'],
      ),
      checkInTime: isAttendance && json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'])
          : null,
      checkOutTime: isAttendance && json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'])
          : null,
      checkInLocation: isAttendance ? json['check_in_location'] : json['location'],
      checkOutLocation: json['check_out_location'],
      statusCheckIn: json['status_check_in'],
      statusCheckOut: json['status_check_out'],
      leaveType: json['type'],
      reason: json['reason'],
      status: json['status'],
      fileProof: json['file_proof'],
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
    );
  }
}

class AdminEmployeeHistoryScreen extends StatefulWidget {
  final int userId;
  final String userName;
  const AdminEmployeeHistoryScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminEmployeeHistoryScreen> createState() => _AdminEmployeeHistoryScreenState();
}

class _AdminEmployeeHistoryScreenState extends State<AdminEmployeeHistoryScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl';

  bool _isLoading = true;
  Map<String, List<HistoryItem>> _groupedHistory = {};

  String selectedMonth = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());
  int selectedYear = DateTime.now().year;
  int selectedMonthNum = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await initializeDateFormatting('id_ID', null);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final token = await _storage.read(key: 'auth_token');
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/employee-history/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<HistoryItem> historyList = data.map((item) => HistoryItem.fromJson(item)).toList();
        _groupHistory(historyList);
      } else {
        _showSnackBar('Gagal memuat riwayat.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan koneksi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _groupHistory(List<HistoryItem> historyList) {
    final grouped = <String, List<HistoryItem>>{};

    for (var item in historyList) {
      if (item.itemType == 'attendance') {
        final itemDate = item.createdAt.toLocal();
        if (itemDate.year != selectedYear || itemDate.month != selectedMonthNum) {
          continue;
        }

        String dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(itemDate);
        grouped.putIfAbsent(dateStr, () => []);
        grouped[dateStr]!.add(item);
      } else {
        if (item.startDate == null || item.endDate == null) continue;

        final startDate = item.startDate!.toLocal();
        final endDate = item.endDate!.toLocal();

        for (var date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
          if (date.year != selectedYear || date.month != selectedMonthNum) {
            continue;
          }

          String dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
          grouped.putIfAbsent(dateStr, () => []);

          final dailyItem = HistoryItem(
            itemType: item.itemType,
            createdAt: date,
            checkInTime: item.checkInTime,
            checkOutTime: item.checkOutTime,
            checkInLocation: item.checkInLocation,
            checkOutLocation: item.checkOutLocation,
            leaveType: item.leaveType,
            reason: item.reason,
            status: item.status,
            fileProof: item.fileProof,
            statusCheckIn: item.statusCheckIn,
            statusCheckOut: item.statusCheckOut,
            startDate: item.startDate,
            endDate: item.endDate,
          );

          grouped[dateStr]!.add(dailyItem);
        }
      }
    }

    if (mounted) setState(() => _groupedHistory = grouped);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _pilihBulan() async {
    final List<String> months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final List<int> years = List.generate(DateTime.now().year - 2020 + 1, (index) => 2020 + index).reversed.toList();

    int tempMonth = selectedMonthNum;
    int tempYear = selectedYear;

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 350,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pilih Periode', style: PoppinsTextStyle.bold.copyWith(fontSize: 18)),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: 20),
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
                      icon: Icon(Icons.arrow_drop_down, color: AppColor.primaryColor),
                      style: PoppinsTextStyle.semiBold.copyWith(fontSize: 16, color: AppColor.primaryColor),
                      items: years.map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
                      onChanged: (value) {
                        if (value != null) setModalState(() => tempYear = value);
                      },
                    ),
                  ),
                  SizedBox(height: 20),
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
                        final isFuture = tempYear > DateTime.now().year || (tempYear == DateTime.now().year && monthNum > DateTime.now().month + 1);

                        return InkWell(
                          onTap: isFuture ? null : () => setModalState(() => tempMonth = monthNum),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppColor.primaryColor : isFuture ? Colors.grey[200] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppColor.primaryColor : Colors.grey[300]!, width: isSelected ? 2 : 1),
                            ),
                            child: Center(
                              child: Text(
                                months[index].substring(0, 3),
                                style: PoppinsTextStyle.medium.copyWith(
                                  fontSize: 13,
                                  color: isSelected ? Colors.white : isFuture ? Colors.grey[400] : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'month': tempMonth, 'year': tempYear}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Pilih', style: PoppinsTextStyle.semiBold.copyWith(fontSize: 16, color: Colors.white)),
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
        selectedMonth = DateFormat('MMMM yyyy', 'id_ID').format(DateTime(selectedYear, selectedMonthNum));
      });
      _loadHistory();
    }
  }

  Future<void> _launchFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      _showSnackBar("File tidak ditemukan.", isError: true);
      return;
    }

    final storageBase = baseUrl.replaceAll(RegExp(r'/api$'), '');
    String cleanPath = filePath.replaceFirst(RegExp(r'^/'), '').replaceFirst(RegExp(r'^storage/'), '');
    final pdfUrl = '$storageBase/storage/$cleanPath';

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF38B2AC).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.picture_as_pdf, color: Color(0xFF38B2AC)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Buka File', style: PoppinsTextStyle.bold.copyWith(fontSize: 18))),
          ],
        ),
        content: Text("Ingin membuka lampiran PDF?", style: PoppinsTextStyle.regular.copyWith(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: PoppinsTextStyle.medium.copyWith(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38B2AC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Buka', style: PoppinsTextStyle.semiBold.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldOpen != true) return;

    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) {
        _showSnackBar("Gagal mengambil file.", isError: true);
        return;
      }

      final bytes = response.bodyBytes;
      final doc = PdfDocument.openData(bytes);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Text("Preview File Bukti", style: PoppinsTextStyle.bold.copyWith(color: Colors.black87, fontSize: 18)),
              centerTitle: true,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: const Color(0xFF38B2AC).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.download_rounded, color: Color(0xFF38B2AC), size: 24),
                    onPressed: () => _downloadPdf(pdfUrl),
                    tooltip: 'Download PDF',
                  ),
                ),
              ],
            ),
            body: Container(color: Colors.grey[200], child: PdfViewPinch(controller: PdfControllerPinch(document: doc))),
          ),
        ),
      );
    } catch (e) {
      _showSnackBar("Terjadi kesalahan: $e", isError: true);
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _showSnackBar("Membuka file di browser...", isError: false);
    } catch (e) {
      _showSnackBar("Gagal membuka file: $e", isError: true);
    }
  }

  Future<String> _getAddressFromCoords(String? coords) async {
    if (coords == null || !coords.contains(',')) return "-";
    try {
      final parts = coords.split(',');
      final lat = double.parse(parts[0]);
      final lon = double.parse(parts[1]);
      final placemarks = await placemarkFromCoordinates(lat, lon);
      final place = placemarks[0];
      return "${place.street}, ${place.locality}";
    } catch (_) {
      return "Gagal memuat alamat";
    }
  }

  String _formatDate(DateTime? dt) => dt == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(dt);
  String _formatDateTime(DateTime dt) => DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt.toLocal());
  String _formatTime(DateTime? dt) => dt == null ? "Belum Absen" : DateFormat('HH:mm', 'id_ID').format(dt);

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('telat') || s.contains('late')) return Colors.orange;
    if (s.contains('overtime')) return const Color(0xFF7C3AED);
    if (s.contains('hadir') || s.contains('on time') || s.contains('ontime') || s.contains('tepat')) return Colors.green;
    return const Color(0xFF94A3B8);
  }

  Color _getApprovalColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'approved': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('Riwayat Kehadiran', style: PoppinsTextStyle.bold.copyWith(color: Colors.black, fontSize: 20)),
            Text(widget.userName, style: PoppinsTextStyle.medium.copyWith(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: _pilihBulan,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColor.primaryColor.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, color: AppColor.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(selectedMonth, style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: AppColor.primaryColor)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down, color: AppColor.primaryColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedHistory.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: AppColor.primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _groupedHistory.keys.length,
                          itemBuilder: (context, index) {
                            final date = _groupedHistory.keys.elementAt(index);
                            final items = _groupedHistory[date]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 20,
                                        decoration: BoxDecoration(color: AppColor.primaryColor, borderRadius: BorderRadius.circular(2)),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(date, style: PoppinsTextStyle.bold.copyWith(fontSize: 16, color: const Color(0xFF2D3748))),
                                    ],
                                  ),
                                ),
                                ...items.map((item) => item.itemType == 'attendance' ? _buildAttendanceCard(item) : _buildLeaveCard(item)),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(HistoryItem item) {
    final isToday = DateUtils.isSameDay(item.createdAt.toLocal(), DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            _buildItemRow(
              icon: Icons.login_rounded,
              iconColor: const Color(0xFF10B981),
              label: 'Absen Masuk',
              time: _formatTime(item.checkInTime),
              address: item.checkInLocation,
              status: item.statusCheckIn,
            ),
            if (item.checkOutTime != null || (item.checkOutTime == null && !isToday)) const Divider(height: 32),
            if (item.checkOutTime != null)
              _buildItemRow(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'Absen Keluar',
                time: _formatTime(item.checkOutTime),
                address: item.checkOutLocation,
                status: item.statusCheckOut,
              ),
            if (item.checkOutTime == null && !isToday)
              _buildItemRow(
                icon: Icons.cancel_rounded,
                iconColor: const Color(0xFF94A3B8),
                label: 'Absen Keluar',
                time: 'Tidak Absen Keluar (Alpha)',
                address: "Karyawan tidak melakukan absen pulang.",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(HistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: _buildApprovalItemRow(
          icon: item.leaveType == 'izin' ? Icons.info_outline_rounded : Icons.calendar_today_rounded,
          iconColor: _getApprovalColor(item.status ?? ''),
          label: item.leaveType == 'izin' ? 'Pengajuan Izin' : 'Pengajuan Cuti',
          approvalStatus: item.status ?? 'pending',
          reason: item.reason,
          startDate: item.startDate,
          endDate: item.endDate,
          createdAt: item.createdAt,
          fileProof: item.fileProof,
          location: item.checkInLocation,
        ),
      ),
    );
  }

  Widget _buildItemRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
    required String? address,
    String? status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: PoppinsTextStyle.semiBold.copyWith(fontSize: 15, color: const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(time, style: PoppinsTextStyle.medium.copyWith(fontSize: 13, color: const Color(0xFF64748B))),
                ],
              ),
              if (status != null && status.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _getStatusColor(status), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(status, style: PoppinsTextStyle.semiBold.copyWith(fontSize: 13, color: _getStatusColor(status))),
                    ],
                  ),
                ),
              ],
              if (address != null && address != "-") ...[
                const SizedBox(height: 6),
                FutureBuilder<String>(
                  future: _getAddressFromCoords(address),
                  builder: (context, snapshot) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            snapshot.data ?? 'Memuat alamat...',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PoppinsTextStyle.regular.copyWith(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalItemRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String approvalStatus,
    required String? reason,
    required DateTime? startDate,
    required DateTime? endDate,
    required DateTime createdAt,
    required String? fileProof,
    String? location,
  }) {
    String statusText;
    switch (approvalStatus) {
      case 'pending':
        statusText = 'Menunggu';
        break;
      case 'approved':
        statusText = 'Disetujui';
        break;
      case 'rejected':
        statusText = 'Ditolak';
        break;
      default:
        statusText = 'Tidak Diketahui';
    }

    final dateRange =
        (startDate != null && endDate != null)
            ? '${_formatDate(startDate)} - ${_formatDate(endDate)}'
            : (startDate != null ? _formatDate(startDate) : '-');

    Widget fileActionButton = InkWell(
      onTap: () => _launchFile(fileProof), // UBAH BARIS INI
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              fileProof != null && fileProof.isNotEmpty
                  ? Icons.file_present_rounded
                  : Icons.info_outline,
              size: 16,
              color:
                  fileProof != null && fileProof.isNotEmpty
                      ? const Color(0xFF38B2AC)
                      : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              fileProof != null && fileProof.isNotEmpty
                  ? 'Buka File Bukti'
                  : 'File Bukti Kosong',
              style: PoppinsTextStyle.medium.copyWith(
                fontSize: 12,
                color:
                    fileProof != null && fileProof.isNotEmpty
                        ? const Color(0xFF38B2AC)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: PoppinsTextStyle.semiBold.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: PoppinsTextStyle.semiBold.copyWith(
                        fontSize: 11,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Periode: $dateRange',
                    style: PoppinsTextStyle.medium.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_filled_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Diajukan: ${_formatDateTime(createdAt)}',
                    style: PoppinsTextStyle.regular.copyWith(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_align_left_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason ?? 'Tidak ada alasan',
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (location != null && location != "-") ...[
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: _getAddressFromCoords(location),
                  builder: (context, snapshot) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            snapshot.data ?? 'Memuat lokasi...',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PoppinsTextStyle.regular.copyWith(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              fileActionButton,
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: AppColor.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Belum Ada Riwayat",
            style: PoppinsTextStyle.bold.copyWith(
              fontSize: 18,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Belum ada riwayat untuk $selectedMonth",
            textAlign: TextAlign.center,
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryInfoBox() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Image.asset(AppImage.history, width: 145, height: 93),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColor.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cek History mu disini",
                    style: PoppinsTextStyle.bold.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tetap semangat, dan jangan lupa untuk selalu tinggalkan jejak absenmu disini.",
                    style: PoppinsTextStyle.regular.copyWith(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
