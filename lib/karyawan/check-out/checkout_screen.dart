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

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://10.0.2.2:8000/api/karyawan';
  
  bool _isLoading = true;
  bool _isSubmitting = false; // Untuk loading tombol
  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  // --- FUNGSI-FUNGSI LOGIKA & API ---

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _currentPosition = currentLatLng;
        });
        _moveCamera(currentLatLng);
      }
      
      await _getAddressFromLatLng(currentLatLng);

    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Layanan lokasi tidak aktif.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Izin lokasi ditolak.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Izin lokasi ditolak permanen, aplikasi tidak dapat meminta izin.');
    } 
    
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      if (mounted) {
        setState(() {
          _currentAddress = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Gagal mendapatkan nama alamat.");
    }
  }

  Future<void> _submitCheckout() async {
    if (_currentPosition == null) {
      _showSnackBar("Lokasi saat ini tidak ditemukan. Coba refresh.", isError: true);
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final token = await _storage.read(key: 'auth_token');
      final url = Uri.parse('$_baseUrl/attendance/check-out');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'latitude': _currentPosition!.latitude.toString(),
          'longitude': _currentPosition!.longitude.toString(),
        },
      ).timeout(const Duration(seconds: 20));
      
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar(responseData['message']);
        // Optional: Kembali ke halaman sebelumnya setelah berhasil
        // Navigator.pop(context); 
      } else {
        _showSnackBar(responseData['message'], isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _moveCamera(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: position, zoom: 17)
    ));
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Absen Pulang",
                          style: PoppinsTextStyle.bold.copyWith(fontSize: 20, color: AppColor.primaryColor),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_pin, color: AppColor.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentAddress,
                                style: PoppinsTextStyle.regular.copyWith(fontSize: 12, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red, // Warna merah untuk checkout
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _isSubmitting ? null : _submitCheckout,
                            child: _isSubmitting
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    "Check Out Sekarang",
                                    style: PoppinsTextStyle.semiBold.copyWith(fontSize: 16, color: AppColor.backgroundColor),
                                  ),
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