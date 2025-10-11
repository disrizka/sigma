import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';

class AdminSlipGajiListScreen extends StatefulWidget {
  const AdminSlipGajiListScreen({super.key});

  @override
  State<AdminSlipGajiListScreen> createState() => _AdminSlipGajiListScreenState();
}

class _AdminSlipGajiListScreenState extends State<AdminSlipGajiListScreen> {
  bool _isLoading = true;
  List<KaryawanSlipGaji> _slipGajiList = [];
  List<KaryawanSlipGaji> _filteredList = [];
  String _selectedBulan = 'Oktober 2025';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _bulanOptions = [
    'Oktober 2025',
    'September 2025',
    'Agustus 2025',
    'Juli 2025',
  ];

  @override
  void initState() {
    super.initState();
    _loadSlipGaji();
  }

  void _loadSlipGaji() {
    // Dummy data slip gaji karyawan
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _slipGajiList = [
          KaryawanSlipGaji(
            id: 1,
            nik: 'KRY001',
            namaKaryawan: 'Budi Santoso',
            jabatan: 'Software Engineer',
            gajiPokok: 8000000,
            tunjangan: 1550000,
            potongan: 650000,
            foto: null,
          ),
          KaryawanSlipGaji(
            id: 2,
            nik: 'KRY002',
            namaKaryawan: 'Siti Nurhaliza',
            jabatan: 'HR Manager',
            gajiPokok: 7500000,
            tunjangan: 1400000,
            potongan: 600000,
            foto: null,
          ),
          KaryawanSlipGaji(
            id: 3,
            nik: 'KRY003',
            namaKaryawan: 'Ahmad Fauzi',
            jabatan: 'Marketing Staff',
            gajiPokok: 5500000,
            tunjangan: 950000,
            potongan: 450000,
            foto: null,
          ),
          KaryawanSlipGaji(
            id: 4,
            nik: 'KRY004',
            namaKaryawan: 'Dewi Lestari',
            jabatan: 'Finance Manager',
            gajiPokok: 9000000,
            tunjangan: 1800000,
            potongan: 750000,
            foto: null,
          ),
          KaryawanSlipGaji(
            id: 5,
            nik: 'KRY005',
            namaKaryawan: 'Eko Prasetyo',
            jabatan: 'UI/UX Designer',
            gajiPokok: 7000000,
            tunjangan: 1300000,
            potongan: 550000,
            foto: null,
          ),
        ];
        _filteredList = _slipGajiList;
        _isLoading = false;
      });
    });
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = _slipGajiList;
      } else {
        _filteredList = _slipGajiList.where((item) {
          return item.namaKaryawan.toLowerCase().contains(query.toLowerCase()) ||
              item.nik.toLowerCase().contains(query.toLowerCase()) ||
              item.jabatan.toLowerCase().contains(query.toLowerCase());
        }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColor.backgroundColor,
        elevation: 0,
        toolbarHeight: 100,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
                ? const Center(child: CircularProgressIndicator())
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
          // Filter Bulan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColor.primaryColor),
            ),
            child: DropdownButton<String>(
              value: _selectedBulan,
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
                    _loadSlipGaji(); // Reload data
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
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
          // Summary Card
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
                      const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 24,
                      ),
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
        return _buildSlipGajiCard(item);
      },
    );
  }

  Widget _buildSlipGajiCard(KaryawanSlipGaji item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
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
                    // Avatar
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColor.primaryColor.withOpacity(0.1),
                      child: Text(
                        item.namaKaryawan.substring(0, 1).toUpperCase(),
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
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
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
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey[300],
                      ),
                      _buildInfoColumn(
                        'Tunjangan',
                        _formatCurrency(item.tunjangan),
                        Colors.blue,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey[300],
                      ),
                      _buildInfoColumn(
                        'Potongan',
                        _formatCurrency(item.potongan),
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
                    color: AppColor.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gaji Bersih',
                        style: PoppinsTextStyle.semiBold.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
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
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data ditemukan',
            style: PoppinsTextStyle.semiBold.copyWith(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coba gunakan kata kunci lain',
            style: PoppinsTextStyle.regular.copyWith(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(KaryawanSlipGaji item) {
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
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Text(
                        item.namaKaryawan.substring(0, 1).toUpperCase(),
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
                          DetailRow('Total Potongan', item.potongan),
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
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Periode: $_selectedBulan',
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
                      style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14),
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
}

// Model untuk Slip Gaji Karyawan
class KaryawanSlipGaji {
  final int id;
  final String nik;
  final String namaKaryawan;
  final String jabatan;
  final int gajiPokok;
  final int tunjangan;
  final int potongan;
  final String? foto;

  KaryawanSlipGaji({
    required this.id,
    required this.nik,
    required this.namaKaryawan,
    required this.jabatan,
    required this.gajiPokok,
    required this.tunjangan,
    required this.potongan,
    this.foto,
  });

  int get gajiBersih => gajiPokok + tunjangan - potongan;
}

// Helper class untuk detail row
class DetailRow {
  final String label;
  final int amount;

  DetailRow(this.label, this.amount);
}