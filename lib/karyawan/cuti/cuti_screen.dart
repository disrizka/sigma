import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key});

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final TextEditingController _alasanController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://10.0.2.2:8000/api/karyawan';

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  // --- FUNGSI-FUNGSI LOGIKA & API ---

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentPosition = currentLatLng);
        await _getAddressFromLatLng(currentLatLng);
      }
    } catch (e) {
      _showElegantSnackBar("Gagal mengambil lokasi: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Layanan lokasi tidak aktif.');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Izin lokasi ditolak permanen.');
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        setState(() {
          _currentAddress = "${place.street}, ${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}";
        });
      }
    } catch (e) {
      if (mounted) _showElegantSnackBar("Gagal mengonversi lokasi: ${e.toString()}", isError: true);
    }
  }

  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate == null || _endDate!.isBefore(_startDate!)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitCuti() async {
    final navigator = Navigator.of(context);
    if (_alasanController.text.trim().isEmpty || _startDate == null || _endDate == null) {
      _showElegantSnackBar("Mohon lengkapi semua field", isError: true);
      return;
    }
    if (_currentPosition == null) {
      _showElegantSnackBar("Gagal mendapatkan lokasi saat ini.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _storage.read(key: 'auth_token');
      var request = http.Request('POST', Uri.parse('$_baseUrl/leave-request'));

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.bodyFields = {
        'type': 'cuti', // Kirim 'cuti' sebagai tipe
        'reason': _alasanController.text,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'location': '${_currentPosition!.latitude},${_currentPosition!.longitude}',
      };

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        _showElegantSnackBar("Pengajuan cuti berhasil dikirim.");
        navigator.pop();
      } else {
        _showElegantSnackBar("Gagal: ${responseData['message']}", isError: true);
      }
    } catch (e) {
      _showElegantSnackBar("Terjadi kesalahan: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showElegantSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundColor,
      body: _isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 17),
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) _controller.complete(controller);
                  },
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: FloatingActionButton(
                    heroTag: "fab_back",
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.white,
                    mini: true,
                    child: Icon(Icons.arrow_back, color: AppColor.primaryColor),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: "fab_refresh",
                    onPressed: _fetchLocation,
                    backgroundColor: Colors.white,
                    mini: true,
                    child: Icon(Icons.my_location, color: AppColor.primaryColor),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Text("Pengajuan Cuti", style: PoppinsTextStyle.bold.copyWith(fontSize: 20, color: AppColor.primaryColor)),
                          ),
                          const SizedBox(height: 16),
                          Text("Pilih Tanggal Cuti", style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildDatePickerField('Dari', _startDate, () => _selectDate(context, isStartDate: true))),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDatePickerField('Sampai', _endDate, () => _selectDate(context, isStartDate: false))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text("Alasan Cuti", style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _alasanController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Tuliskan alasan cuti Anda...",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColor.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _isSubmitting ? null : _submitCuti,
                              child: _isSubmitting
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text("Ajukan Cuti", style: PoppinsTextStyle.semiBold.copyWith(fontSize: 16, color: AppColor.backgroundColor)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildDatePickerField(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          date != null ? DateFormat('d MMM yyyy', 'id_ID').format(date) : 'Pilih',
          style: PoppinsTextStyle.regular.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}