import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sigma/api/api.dart';
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
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$baseUrl/api/karyawan';

  // Taman Wisata Sigantang Nambo
  // static const double LOKASI_LAT = -6.4127;
  // static const double LOKASI_LNG = 106.9168;

  //kampus
  // static const double LOKASI_LAT = -6.3365;
  // static const double LOKASI_LNG = 106.8358;

  //rumah
  static const double LOKASI_LAT = -6.4780242;
  static const double LOKASI_LNG = 106.7645322;
  static const double RADIUS_VALID = 1000;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  double? _distanceFromLocation;
  bool _isInRadius = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _validateRadius(LatLng position) {
    double distance = _calculateDistance(
      position.latitude,
      position.longitude,
      LOKASI_LAT,
      LOKASI_LNG,
    );

    setState(() {
      _distanceFromLocation = distance;
      _isInRadius = distance <= RADIUS_VALID;
    });
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = currentLatLng;
        });

        // 🎯 VALIDASI RADIUS
        _validateRadius(currentLatLng);

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
      return Future.error(
        'Izin lokasi ditolak permanen, aplikasi tidak dapat meminta izin.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];
      if (mounted) {
        setState(() {
          _currentAddress =
              "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        });
      }
    } catch (e) {
      if (mounted)
        setState(() => _currentAddress = "Gagal mendapatkan nama alamat.");
    }
  }

  Future<void> _submitCheckout() async {
    if (_currentPosition == null) {
      _showSnackBar(
        "Lokasi saat ini tidak ditemukan. Coba refresh.",
        isError: true,
      );
      return;
    }

    // 🎯 CEK RADIUS SEBELUM SUBMIT
    if (!_isInRadius) {
      _showSnackBar(
        "Anda berada di luar radius lokasi!\nJarak: ${_distanceFromLocation!.toStringAsFixed(0)}m (Max: ${RADIUS_VALID.toStringAsFixed(0)}m)",
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _storage.read(key: 'auth_token');
      final url = Uri.parse('$_baseUrl/attendance/check-out');

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: {
              'latitude': _currentPosition!.latitude.toString(),
              'longitude': _currentPosition!.longitude.toString(),
            },
          )
          .timeout(const Duration(seconds: 20));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar(responseData['message']);
        Navigator.pop(context); // Kembali setelah berhasil
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
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 17),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
      body:
          _isLoading || _currentPosition == null
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
                      if (!_controller.isCompleted)
                        _controller.complete(controller);
                    },
                    // 🎯 TAMPILKAN CIRCLE RADIUS LOKASI
                    circles: {
                      Circle(
                        circleId: const CircleId('lokasi_radius'),
                        center: const LatLng(LOKASI_LAT, LOKASI_LNG),
                        radius: RADIUS_VALID,
                        fillColor: Colors.red.withOpacity(0.1),
                        strokeColor: Colors.red,
                        strokeWidth: 2,
                      ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('lokasi'),
                        position: const LatLng(LOKASI_LAT, LOKASI_LNG),
                        infoWindow: const InfoWindow(
                          title: 'Universitas Pancasila',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
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
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColor.primaryColor,
                      ),
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
                      child: Icon(
                        Icons.my_location,
                        color: AppColor.primaryColor,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Absen Pulang",
                            style: PoppinsTextStyle.bold.copyWith(
                              fontSize: 20,
                              color: AppColor.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 🎯 TAMPILKAN STATUS RADIUS
                          if (_distanceFromLocation != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    _isInRadius
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      _isInRadius ? Colors.green : Colors.red,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isInRadius
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color:
                                        _isInRadius ? Colors.green : Colors.red,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isInRadius
                                              ? "Lokasi Valid ✓"
                                              : "Lokasi Tidak Valid ✗",
                                          style: PoppinsTextStyle.semiBold
                                              .copyWith(
                                                fontSize: 14,
                                                color:
                                                    _isInRadius
                                                        ? Colors.green.shade700
                                                        : Colors.red.shade700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Jarak: ${_distanceFromLocation!.toStringAsFixed(0)}m dari lokasi",
                                          style: PoppinsTextStyle.regular
                                              .copyWith(
                                                fontSize: 11,
                                                color: Colors.black87,
                                              ),
                                        ),
                                        if (!_isInRadius)
                                          Text(
                                            "Max radius: ${RADIUS_VALID.toStringAsFixed(0)}m",
                                            style: PoppinsTextStyle.regular
                                                .copyWith(
                                                  fontSize: 10,
                                                  color: Colors.red.shade600,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_pin,
                                color: AppColor.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  style: PoppinsTextStyle.regular.copyWith(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isInRadius ? Colors.red : Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed:
                                  (_isSubmitting || !_isInRadius)
                                      ? null
                                      : _submitCheckout,
                              child:
                                  _isSubmitting
                                      ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        _isInRadius
                                            ? "Check Out Sekarang"
                                            : "Diluar Jangkauan",
                                        style: PoppinsTextStyle.semiBold
                                            .copyWith(
                                              fontSize: 16,
                                              color: AppColor.backgroundColor,
                                            ),
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
