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
import 'package:url_launcher/url_launcher.dart';

class HistoryItem {
  final String itemType;
  final DateTime createdAt;
  final DateTime? checkInTime, checkOutTime, startDate, endDate;
  final String? checkInLocation, checkOutLocation, leaveType, reason, status,
      fileProof, statusCheckIn, statusCheckOut;

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
      checkInLocation:
          isAttendance ? json['check_in_location'] : json['location'],
      checkOutLocation: json['check_out_location'],
      statusCheckIn: json['status_check_in'],
      statusCheckOut: json['status_check_out'],
      leaveType: json['type'],
      reason: json['reason'],
      status: json['status'],
      fileProof: json['file_proof'],
      startDate:
          json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
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
  State<AdminEmployeeHistoryScreen> createState() =>
      _AdminEmployeeHistoryScreenState();
}

class _AdminEmployeeHistoryScreenState extends State<AdminEmployeeHistoryScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl';
  bool _isLoading = true;
  Map<String, List<HistoryItem>> _groupedHistory = {};
  String selectedMonth = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());
  int selectedYear = DateTime.now().year;
  int selectedMonthNum = DateTime.now().month;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoadData() async {
    await initializeDateFormatting('id_ID', null);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _fadeController.reset();

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
        final List<HistoryItem> historyList =
            data.map((item) => HistoryItem.fromJson(item)).toList();
        _groupHistory(historyList);
        _fadeController.forward();
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
        if (itemDate.year != selectedYear || itemDate.month != selectedMonthNum)
          continue;

        String dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(itemDate);
        grouped.putIfAbsent(dateStr, () => []).add(item);
      } else {
        if (item.startDate == null || item.endDate == null) continue;

        final startDate = item.startDate!.toLocal();
        final endDate = item.endDate!.toLocal();

        for (var date = startDate;
            date.isBefore(endDate.add(Duration(days: 1)));
            date = date.add(Duration(days: 1))) {
          if (date.year != selectedYear || date.month != selectedMonthNum)
            continue;

          String dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
          grouped.putIfAbsent(dateStr, () => []).add(
                HistoryItem(
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
                ),
              );
        }
      }
    }

    if (mounted) setState(() => _groupedHistory = grouped);
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
            Expanded(
              child: Text(
                message,
                style: PoppinsTextStyle.medium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pilihBulan() async {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final years = List.generate(
      DateTime.now().year - 2020 + 1,
      (index) => 2020 + index,
    ).reversed.toList();

    int tempMonth = selectedMonthNum;
    int tempYear = selectedYear;

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Periode',
                          style: PoppinsTextStyle.bold.copyWith(
                            fontSize: 24,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColor.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColor.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: tempYear,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: AppColor.primaryColor),
                        style: PoppinsTextStyle.bold.copyWith(
                          fontSize: 18,
                          color: AppColor.primaryColor,
                        ),
                        items: years
                            .map((year) => DropdownMenuItem(
                                  value: year,
                                  child: Text('$year'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setModalState(() => tempYear = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final monthNum = index + 1;
                          final isSelected = tempMonth == monthNum;
                          final isFuture = tempYear > DateTime.now().year ||
                              (tempYear == DateTime.now().year &&
                                  monthNum > DateTime.now().month + 1);

                          return InkWell(
                            onTap: isFuture
                                ? null
                                : () => setModalState(() => tempMonth = monthNum),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColor.primaryColor
                                    : isFuture
                                        ? Colors.grey[100]
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColor.primaryColor
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColor.primaryColor.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  months[index].substring(0, 3),
                                  style: PoppinsTextStyle.bold.copyWith(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : isFuture
                                            ? Colors.grey[400]
                                            : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, {
                          'month': tempMonth,
                          'year': tempYear,
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Terapkan',
                          style: PoppinsTextStyle.bold.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
        selectedMonth = DateFormat('MMMM yyyy', 'id_ID')
            .format(DateTime(selectedYear, selectedMonthNum));
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
    String cleanPath = filePath
        .replaceFirst(RegExp(r'^/'), '')
        .replaceFirst(RegExp(r'^storage/'), '');
    final pdfUrl = '$storageBase/storage/$cleanPath';

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF38B2AC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFF38B2AC),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Buka File PDF',
                style: PoppinsTextStyle.bold.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                "Apakah Anda ingin membuka lampiran PDF ini?",
                textAlign: TextAlign.center,
                style: PoppinsTextStyle.regular.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: PoppinsTextStyle.semiBold.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38B2AC),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Buka',
                        style: PoppinsTextStyle.bold.copyWith(color: Colors.white),
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

    if (shouldOpen != true) return;

    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) {
        _showSnackBar("Gagal mengambil file.", isError: true);
        return;
      }

      final doc = PdfDocument.openData(response.bodyBytes);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                "Preview File",
                style: PoppinsTextStyle.bold.copyWith(fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadPdf(pdfUrl),
                ),
              ],
            ),
            body: PdfViewPinch(
              controller: PdfControllerPinch(document: doc),
            ),
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
      _showSnackBar("Membuka file di browser...");
    } catch (e) {
      _showSnackBar("Gagal membuka file: $e", isError: true);
    }
  }

  Future<String> _getAddressFromCoords(String? coords) async {
    if (coords == null || !coords.contains(',')) return "-";
    try {
      final parts = coords.split(',');
      final placemarks = await placemarkFromCoordinates(
        double.parse(parts[0]),
        double.parse(parts[1]),
      );
      final place = placemarks[0];
      return "${place.street}, ${place.locality}";
    } catch (_) {
      return "Gagal memuat alamat";
    }
  }

  String _formatDate(DateTime? dt) =>
      dt == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(dt);
  String _formatDateTime(DateTime dt) =>
      DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt.toLocal());
  String _formatTime(DateTime? dt) =>
      dt == null ? "Belum Absen" : DateFormat('HH:mm', 'id_ID').format(dt);

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('telat') || s.contains('late')) return const Color(0xFFF59E0B);
    if (s.contains('overtime')) return const Color(0xFF7C3AED);
    if (s.contains('hadir') || s.contains('on time') || s.contains('tepat'))
      return const Color(0xFF10B981);
    return const Color(0xFF94A3B8);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _groupedHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 80,
      centerTitle: true,
      leading: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.history, color: AppColor.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Riwayat Kehadiran',
                style: PoppinsTextStyle.bold.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.userName,
              style: PoppinsTextStyle.semiBold.copyWith(
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: _pilihBulan,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColor.primaryColor.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColor.primaryColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month, color: AppColor.primaryColor, size: 22),
              const SizedBox(width: 12),
              Text(
                selectedMonth,
                style: PoppinsTextStyle.bold.copyWith(
                  fontSize: 16,
                  color: AppColor.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down, color: AppColor.primaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColor.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat riwayat...',
            style: PoppinsTextStyle.medium.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColor.primaryColor,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          itemCount: _groupedHistory.keys.length,
          itemBuilder: (context, index) {
            final date = _groupedHistory.keys.elementAt(index);
            final items = _groupedHistory[date]!;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 40)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 15 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateHeader(date, items.length),
                  ...items.map((item) => item.itemType == 'attendance'
                      ? _buildAttendanceCard(item)
                      : _buildLeaveCard(item)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              date,
              style: PoppinsTextStyle.bold.copyWith(fontSize: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: PoppinsTextStyle.bold.copyWith(
                fontSize: 12,
                color: Colors.grey[700],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAttendanceRow(
            icon: Icons.login,
            iconColor: const Color(0xFF10B981),
            label: 'Masuk',
            time: _formatTime(item.checkInTime),
            address: item.checkInLocation,
            status: item.statusCheckIn,
          ),
          if (item.checkOutTime != null || !isToday) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.grey[200], height: 1),
            ),
            if (item.checkOutTime != null)
              _buildAttendanceRow(
                icon: Icons.logout,
                iconColor: const Color(0xFFEF4444),
                label: 'Keluar',
                time: _formatTime(item.checkOutTime),
                address: item.checkOutLocation,
                status: item.statusCheckOut,
              )
            else
              _buildAttendanceRow(
                icon: Icons.cancel,
                iconColor: Colors.grey,
                label: 'Keluar',
                time: 'Alpha',
                address: null,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaveCard(HistoryItem item) {
    final icon = item.leaveType == 'izin' ? Icons.info_outline : Icons.event;
    final statusColor = _getApprovalColor(item.status ?? '');
    final statusText = {'pending': 'Menunggu', 'approved': 'Disetujui', 'rejected': 'Ditolak'}[item.status] ?? 'Unknown';
    final dateRange = item.startDate != null && item.endDate != null
        ? '${_formatDate(item.startDate)} - ${_formatDate(item.endDate)}'
        : _formatDate(item.startDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.leaveType == 'izin' ? 'Izin' : 'Cuti',
                        style: PoppinsTextStyle.bold.copyWith(fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: PoppinsTextStyle.bold.copyWith(
                          fontSize: 11,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.date_range, dateRange, Colors.grey[600]!),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.access_time, _formatDateTime(item.createdAt), Colors.grey[500]!, fontSize: 11),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.reason ?? 'Tidak ada alasan',
                          style: PoppinsTextStyle.regular.copyWith(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.checkInLocation != null && item.checkInLocation != "-") ...[
                  const SizedBox(height: 10),
                  FutureBuilder<String>(
                    future: _getAddressFromCoords(item.checkInLocation),
                    builder: (context, snapshot) => _buildInfoRow(
                      Icons.location_on,
                      snapshot.data ?? 'Memuat...',
                      Colors.grey[500]!,
                      maxLines: 2,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _launchFile(item.fileProof),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: item.fileProof != null && item.fileProof!.isNotEmpty
                          ? const Color(0xFF38B2AC).withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.fileProof != null && item.fileProof!.isNotEmpty
                            ? const Color(0xFF38B2AC).withOpacity(0.3)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.fileProof != null && item.fileProof!.isNotEmpty
                              ? Icons.file_present
                              : Icons.info_outline,
                          size: 18,
                          color: item.fileProof != null && item.fileProof!.isNotEmpty
                              ? const Color(0xFF38B2AC)
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.fileProof != null && item.fileProof!.isNotEmpty
                              ? 'Lihat File'
                              : 'Tidak Ada File',
                          style: PoppinsTextStyle.semiBold.copyWith(
                            fontSize: 12,
                            color: item.fileProof != null && item.fileProof!.isNotEmpty
                                ? const Color(0xFF38B2AC)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
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

  Widget _buildAttendanceRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
    String? address,
    String? status,
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
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: PoppinsTextStyle.bold.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.access_time, time, Colors.grey[600]!),
              if (status != null && status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: PoppinsTextStyle.bold.copyWith(
                          fontSize: 11,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (address != null && address != "-") ...[
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: _getAddressFromCoords(address),
                  builder: (context, snapshot) => _buildInfoRow(
                    Icons.location_on,
                    snapshot.data ?? 'Memuat...',
                    Colors.grey[500]!,
                    maxLines: 2,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    Color color, {
    int maxLines = 1,
    double fontSize = 12,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: PoppinsTextStyle.medium.copyWith(
              fontSize: fontSize,
              color: color,
              height: 1.3,
            ),
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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: 64,
              color: AppColor.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Belum Ada Riwayat",
            style: PoppinsTextStyle.bold.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Belum ada riwayat untuk periode $selectedMonth",
              textAlign: TextAlign.center,
              style: PoppinsTextStyle.regular.copyWith(
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }}