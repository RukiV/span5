import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_colors.dart';

class LocationPage extends StatefulWidget {
  /// Valt terug op hierdie kampus-posisie wanneer geen kaartpunt bekend is
  /// (byvoorbeeld 'n nuwe verslag sonder 'n geselekteerde ligging).
  static const LatLng defaultLocation = LatLng(-25.850400, 28.179350);
  final LatLng? initialLocation;
  const LocationPage({super.key, this.initialLocation});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  LatLng _selectedLocation = LocationPage.defaultLocation;
  LatLng? _userLocation;
  bool _gpsPermissionDenied = false;
  bool _isSnapping = false;
  bool _userPicked = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGps());
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsPermissionDenied = true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (mounted) setState(() => _gpsPermissionDenied = false);
      _startTracking();
    } else {
      if (mounted) setState(() => _gpsPermissionDenied = true);
    }
  }

  void _startTracking() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      );
      _handleNewPosition(position, moveMap: true);
    } catch (_) {}

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      _handleNewPosition(position, moveMap: false);
    });
  }

  void _handleNewPosition(Position position, {bool moveMap = false}) {
    if (!mounted) return;
    final userPoint = LatLng(position.latitude, position.longitude);

    setState(() {
      _userLocation = userPoint;
      if (!_userPicked) _selectedLocation = userPoint;
    });

    if (moveMap) {
      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(userPoint, 18.0));
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _isSnapping = true);

    try {
      final Uint8List? imageBytes = await _mapController?.takeSnapshot();

      if (mounted) {
        Navigator.pop(context, {
          'location': _selectedLocation,
          'screenshot': imageBytes,
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context, null);
    } finally {
      if (mounted) setState(() => _isSnapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Kies Ligging"),
        actions: [
          if (!_isSnapping)
            IconButton(
                icon: const Icon(Icons.check, color: AppColors.gold),
                onPressed: _confirmLocation),
          IconButton(
            icon: Icon(_gpsPermissionDenied ? Icons.refresh : Icons.my_location,
                color: _gpsPermissionDenied ? AppColors.gold : AppColors.gold),
            onPressed: () {
              if (_gpsPermissionDenied) {
                _initGps();
              } else if (_userLocation != null) {
                _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_userLocation!, 18.0));
              }
            },
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          tooltip: "Gebruik my ligging",
          onPressed: () {
            if (_userLocation != null) {
              setState(() {
                _selectedLocation = _userLocation!;
                _userPicked = true;
              });
              _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_userLocation!, 18.0));
            } else {
              _initGps();
            }
          },
          child: const Icon(Icons.my_location, color: AppColors.navy),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _selectedLocation, zoom: 15),
            onMapCreated: (c) => _mapController = c,
            onTap: (latLng) {
              setState(() {
                _selectedLocation = latLng;
                _userPicked = true;
              });
            },
            myLocationEnabled: !_gpsPermissionDenied,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                    _userPicked = true;
                  });
                },
              ),
            },
            circles: {},
          ),
          if (_gpsPermissionDenied)
            Container(
              color: Colors.white,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined,
                      size: 100,
                      color: AppColors.navy.withValues(alpha: 50 / 255)),
                  const SizedBox(height: 25),
                  const Text("Geen GPS Toegang",
                      style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                        "Aktiveer jou GPS om jou huidige ligging op die kaart te sien.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                ],
              ),
            ),
          if (_isSnapping)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.gold),
                    SizedBox(height: 15),
                    Text("Ligging word vasgelê...",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
