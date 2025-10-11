import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({super.key});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final TextEditingController _alasanController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://10.0.2.2:8000/api/karyawan';

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  File? _selectedFile;
  String? _fileName;

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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result != null && result.files.first.path != null) {
        setState(() {
          _selectedFile = File(result.files.first.path!);
          _fileName = result.files.first.name;
        });
        _showElegantSnackBar("File berhasil dipilih: $_fileName");
      }
    } catch (e) {
      _showElegantSnackBar("Error memilih file: ${e.toString()}", isError: true);
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
    });
    _showElegantSnackBar("File dihapus");
  }

  Future<void> _submitIzin() async {
    final navigator = Navigator.of(context);
    if (_alasanController.text.trim().isEmpty) {
      _showElegantSnackBar("Mohon isi alasan izin terlebih dahulu", isError: true);
      return;
    }
    if (_currentPosition == null) {
      _showElegantSnackBar("Gagal mendapatkan lokasi saat ini.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _storage.read(key: 'auth_token');
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/leave-request'));

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['type'] = 'izin';
      request.fields['reason'] = _alasanController.text;
      request.fields['start_date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      request.fields['end_date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      request.fields['location'] = '${_currentPosition!.latitude},${_currentPosition!.longitude}';

      if (_selectedFile != null) {
        request.files.add(await http.MultipartFile.fromPath('file_proof', _selectedFile!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        _showElegantSnackBar("Pengajuan izin berhasil dikirim.");
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
      ),
    );
  }

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
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 17,
                  ),
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
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Text(
                              "Pengajuan Izin",
                              style: PoppinsTextStyle.bold.copyWith(fontSize: 20, color: AppColor.primaryColor),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_pin, color: AppColor.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  style: PoppinsTextStyle.regular.copyWith(fontSize: 11, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Alasan Izin",
                            style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _alasanController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: "Tuliskan alasan izin Anda...",
                              hintStyle: PoppinsTextStyle.regular.copyWith(fontSize: 12, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            style: PoppinsTextStyle.regular.copyWith(fontSize: 12, color: Colors.black),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Lampiran (Opsional)",
                            style: PoppinsTextStyle.semiBold.copyWith(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          if (_selectedFile == null)
                            InkWell(
                              onTap: _pickFile,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file, color: AppColor.primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Upload File (pdf, doc, docx)",
                                      style: PoppinsTextStyle.medium.copyWith(fontSize: 13, color: AppColor.primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[300]!, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.insert_drive_file, color: Colors.green[700], size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _fileName ?? "",
                                          style: PoppinsTextStyle.medium.copyWith(fontSize: 12, color: Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "File berhasil dipilih",
                                          style: PoppinsTextStyle.regular.copyWith(fontSize: 10, color: Colors.green[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _removeFile,
                                    icon: Icon(Icons.close, color: Colors.red[400]),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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
                              onPressed: _isSubmitting ? null : _submitIzin,
                              child: _isSubmitting
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    "Kirim Izin",
                                    style: PoppinsTextStyle.semiBold.copyWith(fontSize: 16, color: AppColor.backgroundColor),
                                  ),
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
}