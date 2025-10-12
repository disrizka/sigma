import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sigma/karyawan/main/bottom_navigation_bar.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';

// === MODEL DATA ===
class HistoryItem {
  final int id;
  final String itemType; // 'attendance' atau 'leave_request'

  // Attendance
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String? statusCheckIn; // <- ditambahkan
  final String? statusCheckOut; // <- ditambahkan

  // Leave Request
  final String? leaveType;
  final String reason;
  final String? status;

  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.itemType,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.statusCheckIn,
    this.statusCheckOut,
    this.leaveType,
    this.reason = "Tidak ada alasan",
    this.status,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    bool isAttendance = json.containsKey('date');
    if (isAttendance) {
      return HistoryItem(
        id: json['id'],
        itemType: 'attendance',
        checkInTime:
            json['check_in_time'] != null
                ? DateTime.parse(json['check_in_time'])
                : null,
        checkOutTime:
            json['check_out_time'] != null
                ? DateTime.parse(json['check_out_time'])
                : null,
        checkInLocation: json['check_in_location'],
        checkOutLocation: json['check_out_location'],
        statusCheckIn: json['status_check_in'], // parse dari json
        statusCheckOut: json['status_check_out'], // parse dari json
        createdAt: DateTime.parse(json['date']),
      );
    } else {
      return HistoryItem(
        id: json['id'],
        itemType: 'leave_request',
        leaveType: json['type'],
        reason: json['reason'] ?? "Tidak ada alasan",
        status: json['status'],
        createdAt: DateTime.parse(json['start_date']),
      );
    }
  }
}

// === HISTORY SCREEN ===
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://10.0.2.2:8000/api/karyawan';

  bool _isLoading = true;
  Map<String, List<HistoryItem>> _groupedHistory = {};

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
        Uri.parse('$_baseUrl/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<HistoryItem> historyList =
            data.map((item) => HistoryItem.fromJson(item)).toList();
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
      String dateStr = DateFormat(
        'EEEE, d MMMM yyyy',
        'id_ID',
      ).format(item.createdAt.toLocal());
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(item);
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

  // === UI ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed:
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BottomBar()),
              ),
        ),
        title: Text(
          'Riwayat Kehadiran',
          style: PoppinsTextStyle.bold.copyWith(
            color: Colors.black,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHistoryInfoBox(),
          const SizedBox(height: 8),
          Expanded(
            child:
                _isLoading
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
                                padding: const EdgeInsets.fromLTRB(
                                  4,
                                  20,
                                  4,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColor.primaryColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      date,
                                      style: PoppinsTextStyle.bold.copyWith(
                                        fontSize: 16,
                                        color: const Color(0xFF2D3748),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...items.map(_buildHistoryItem),
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

  Widget _buildHistoryItem(HistoryItem item) =>
      item.itemType == 'attendance'
          ? _buildAttendanceCard(item)
          : _buildLeaveCard(item);

  Widget _buildAttendanceCard(HistoryItem item) {
    final isToday = DateUtils.isSameDay(
      item.createdAt.toLocal(),
      DateTime.now(),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
              status: item.statusCheckIn, // <-- kirim status checkin
            ),
            if (item.checkOutTime != null ||
                (item.checkOutTime == null && !isToday))
              const Divider(height: 32),
            if (item.checkOutTime != null)
              _buildItemRow(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'Absen Keluar',
                time: _formatTime(item.checkOutTime),
                address: item.checkOutLocation,
                status: item.statusCheckOut, // <-- kirim status checkout
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: _buildApprovalItemRow(
          icon:
              item.leaveType == 'izin'
                  ? Icons.info_outline_rounded
                  : Icons.calendar_today_rounded,
          iconColor: _getApprovalColor(item.status ?? ''),
          label: item.leaveType == 'izin' ? 'Pengajuan Izin' : 'Pengajuan Cuti',
          approvalStatus: item.status ?? 'pending',
          reason: item.reason,
        ),
      ),
    );
  }

  Color _getApprovalColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
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

  Widget _buildItemRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
    required String? address,
    String? status, // <-- parameter status tambahan
  }) {
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
              Text(
                label,
                style: PoppinsTextStyle.semiBold.copyWith(
                  fontSize: 15,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: PoppinsTextStyle.medium.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (status != null && status.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 13,
                          color: _getStatusColor(status),
                        ),
                      ),
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
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            snapshot.data ?? 'Memuat alamat...',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PoppinsTextStyle.regular.copyWith(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                              height: 1.4,
                            ),
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

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('telat') || s.contains('late')) return Colors.orange;
    if (s.contains('overtime')) return const Color(0xFF7C3AED); // ungu-ish
    if (s.contains('hadir') ||
        s.contains('on time') ||
        s.contains('ontime') ||
        s.contains('tepat'))
      return Colors.green;
    // default
    return const Color(0xFF94A3B8);
  }

  Widget _buildApprovalItemRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String approvalStatus,
    required String reason,
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reason,
                        style: PoppinsTextStyle.regular.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? dt) =>
      dt == null ? "Belum Absen" : DateFormat('HH:mm', 'id_ID').format(dt);

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
            "Yuk mulai absensimu hari ini!",
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
