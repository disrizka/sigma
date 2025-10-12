import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/date_symbol_data_local.dart';

class HistoryItem {
  final String itemType;
  final DateTime createdAt;
  final DateTime? checkInTime, checkOutTime;
  final String? checkInLocation, checkOutLocation;
  final String? leaveType, reason, status, fileProof;
  final String? statusCheckIn, statusCheckOut;

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
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    bool isAttendance = json.containsKey('date');
    return HistoryItem(
      itemType: isAttendance ? 'attendance' : 'leave_request',
      createdAt: DateTime.parse(isAttendance ? json['date'] : json['start_date']),
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
  State<AdminEmployeeHistoryScreen> createState() =>
      _AdminEmployeeHistoryScreenState();
}

class _AdminEmployeeHistoryScreenState
    extends State<AdminEmployeeHistoryScreen> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://10.0.2.2:8000';
  bool _isLoading = true;
  Map<String, List<HistoryItem>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadHistory();
    });
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
        final historyList =
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
      if (grouped[dateStr] == null) grouped[dateStr] = [];
      grouped[dateStr]!.add(item);
    }
    if (mounted) setState(() => _groupedHistory = grouped);
  }

  void _showLocationMap(String locationString, String title) {
    if (!locationString.contains(',')) {
      _showSnackBar('Data lokasi tidak valid.', isError: true);
      return;
    }
    final parts = locationString.split(',');
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);

    if (lat == null || lon == null) return;
    final location = LatLng(lat, lon);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColor.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: PoppinsTextStyle.bold.copyWith(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 400,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: location,
                  zoom: 17,
                ),
                markers: {
                  Marker(markerId: MarkerId(title), position: location),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      _showSnackBar("File tidak ditemukan.", isError: true);
      return;
    }

    final url = Uri.parse('$_baseUrl/storage/$filePath');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("Tidak bisa membuka file: $url", isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Riwayat Karyawan',
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 18,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              widget.userName,
              style: PoppinsTextStyle.medium.copyWith(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedHistory.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedHistory.keys.length,
                    itemBuilder: (context, index) {
                      final date = _groupedHistory.keys.elementAt(index);
                      final items = _groupedHistory[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateHeader(date, index == 0),
                          ...items.map((item) => _buildHistoryItem(item)),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDateHeader(String date, bool isFirst) {
    return Container(
      margin: EdgeInsets.only(bottom: 16, top: isFirst ? 0 : 24),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            date,
            style: PoppinsTextStyle.bold.copyWith(
              fontSize: 16,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(HistoryItem item) {
    if (item.itemType == 'attendance') {
      return _buildAttendanceCard(item);
    } else if (item.itemType == 'leave_request') {
      return _buildLeaveCard(item);
    }
    return const SizedBox.shrink();
  }

  Widget _buildAttendanceCard(HistoryItem item) {
    final isToday = DateUtils.isSameDay(item.createdAt.toLocal(), DateTime.now());
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildAttendanceRow(
              'Check In',
              item.checkInTime,
              item.checkInLocation,
              Icons.login_rounded,
              const Color(0xFF10B981),
              item.statusCheckIn,
            ),
            Container(height: 1, color: Colors.grey[200]),
            // Tampilkan checkout atau status alpha
            if (item.checkOutTime != null)
              _buildAttendanceRow(
                'Check Out',
                item.checkOutTime,
                item.checkOutLocation,
                Icons.logout_rounded,
                const Color(0xFFEF4444),
                item.statusCheckOut,
              )
            else if (!isToday)
              _buildAttendanceRow(
                'Check Out',
                null,
                null,
                Icons.cancel_rounded,
                const Color(0xFF94A3B8),
                'Alpha',
              )
            else
              _buildAttendanceRow(
                'Check Out',
                null,
                null,
                Icons.logout_rounded,
                const Color(0xFFEF4444),
                null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(HistoryItem item) {
    final color = _getApprovalColor(item.status ?? 'pending');
    final icon = item.leaveType == 'izin'
        ? Icons.info_rounded
        : Icons.event_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildApprovalItemRow(
                icon: icon,
                iconColor: color,
                label: 'Pengajuan ${item.leaveType?.toUpperCase() ?? 'N/A'}',
                approvalStatus: item.status ?? 'pending',
                reason: item.reason ?? 'Tidak ada alasan',
              ),
            ),
            if ((item.checkInLocation != null &&
                    item.checkInLocation!.isNotEmpty) ||
                (item.fileProof != null && item.fileProof!.isNotEmpty))
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Material(
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (item.checkInLocation != null &&
                            item.checkInLocation!.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _showLocationMap(
                                item.checkInLocation!, 'Lokasi Pengajuan'),
                            icon: Icon(Icons.map_outlined,
                                size: 16, color: Colors.grey.shade700),
                            label: Text('Lihat Lokasi',
                                style: PoppinsTextStyle.medium.copyWith(
                                    color: Colors.grey.shade700, fontSize: 12)),
                          ),
                        if (item.fileProof != null && item.fileProof!.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _launchFile(item.fileProof),
                            icon: Icon(Icons.attachment_rounded,
                                size: 16, color: Colors.grey.shade700),
                            label: Text('Lihat Lampiran',
                                style: PoppinsTextStyle.medium.copyWith(
                                    color: Colors.grey.shade700, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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
        return Colors.grey;
    }
  }

  Widget _buildAttendanceRow(
    String title,
    DateTime? time,
    String? location,
    IconData icon,
    Color color,
    String? status,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PoppinsTextStyle.semiBold.copyWith(
                    color: color,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      time != null
                          ? DateFormat('HH:mm').format(time.toLocal())
                          : (status == 'Alpha' ? 'Tidak Hadir' : 'Belum Absen'),
                      style: PoppinsTextStyle.regular.copyWith(
                        color: time != null ? Colors.black87 : Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                // Tampilkan status chip
                if (status != null && status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildStatusChip(status),
                ],
              ],
            ),
          ),
          if (time != null && location != null && location.isNotEmpty)
            IconButton(
              icon: Icon(Icons.map_rounded,
                  color: Theme.of(context).primaryColor, size: 20),
              onPressed: () => _showLocationMap(location, 'Lokasi $title'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 12,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    
    // Telat/Late
    if (s.contains('telat') || s.contains('late')) {
      return const Color(0xFFF59E0B); // Orange
    }
    
    // Overtime
    if (s.contains('overtime') || s.contains('lembur')) {
      return const Color(0xFF7C3AED); // Purple
    }
    
    // Pulang Lebih Awal
    if (s.contains('pulang lebih awal') || s.contains('early')) {
      return const Color(0xFFEF4444); // Red
    }
    
    // Tepat Waktu / On Time
    if (s.contains('tepat waktu') || 
        s.contains('ontime') || 
        s.contains('on time') ||
        s.contains('hadir')) {
      return const Color(0xFF10B981); // Green
    }
    
    // Alpha
    if (s.contains('alpha')) {
      return const Color(0xFF94A3B8); // Gray
    }
    
    // Default
    return const Color(0xFF64748B);
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
        statusText = 'N/A';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: PoppinsTextStyle.bold.copyWith(
                  color: iconColor,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: PoppinsTextStyle.semiBold.copyWith(
                  color: iconColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description_rounded,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alasan',
                      style: PoppinsTextStyle.medium.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: PoppinsTextStyle.regular.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade800,
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
            child: Icon(Icons.history, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Riwayat Absensi',
            style: PoppinsTextStyle.bold.copyWith(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Riwayat absensi akan muncul di sini',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}