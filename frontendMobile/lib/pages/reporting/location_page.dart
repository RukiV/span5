import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart' as model;

class LocationPage extends StatefulWidget {
  final bool autoConfirm;
  const LocationPage({super.key, this.autoConfirm = false});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  
  LatLng _selectedLocation = const LatLng(-25.850400, 28.179350);
  LatLng? _userLocation; 
  model.Campus? _activeCampus;
  bool _isManualMode = true;
  bool _hasPoint = false;
  bool _isSnapping = false;
  bool _gpsPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _activeCampus = null;
    if (CampusService.campusesNotifier.value.isNotEmpty) {
      final first = CampusService.campusesNotifier.value.first;
      _selectedLocation = LatLng(first.location.latitude, first.location.longitude);
    }
    _hasPoint = true; 
    _isSnapping = false;

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
      if (mounted) {
        setState(() {
          _isManualMode = true;
          _gpsPermissionDenied = true;
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      if (mounted) {
        setState(() {
          _isManualMode = false;
          _gpsPermissionDenied = false;
        });
        _startTracking();
      }
    } else {
      if (mounted) {
        setState(() {
          _isManualMode = true;
          _gpsPermissionDenied = true;
        });
      }
    }
  }

  void _startTracking() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _handleNewPosition(position, moveMap: true);
    } catch (_) {}

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1)
    ).listen((Position position) {
      _handleNewPosition(position, moveMap: false);
    });
  }

  void _handleNewPosition(Position position, {bool moveMap = false}) {
    if (!mounted) return;
    final userPoint = LatLng(position.latitude, position.longitude);
    setState(() {
      _userLocation = userPoint;
      _updateActiveCampus(userPoint);
    });
    if (moveMap && _isPointInsideAnyCampus(userPoint)) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userPoint, 18.0));
    }
  }

  void _updateActiveCampus(LatLng point) {
    model.Campus? foundCampus;
    for (var campus in CampusService.campusesNotifier.value) {
      double distance = Geolocator.distanceBetween(
        point.latitude, point.longitude, 
        campus.location.latitude, campus.location.longitude
      );
      if (distance <= campus.radius) {
        foundCampus = campus;
        break;
      }
    }
    setState(() => _activeCampus = foundCampus);
  }

  bool _isPointInsideAnyCampus(LatLng point) {
    for (var campus in CampusService.campusesNotifier.value) {
      double distance = Geolocator.distanceBetween(
        point.latitude, point.longitude, 
        campus.location.latitude, campus.location.longitude
      );
      if (distance <= campus.radius) return true;
    }
    return false;
  }

  Future<void> _confirmLocation() async {
    if (!_isPointInsideAnyCampus(_selectedLocation)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kies 'n punt binne 'n toegelate kampus area."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSnapping = true);

    try {
      final Uint8List? imageBytes = await _mapController?.takeSnapshot();

      if (mounted) {
        Navigator.pop(context, {
          'coords': "${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}",
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
    bool isOffCampus = _userLocation != null && _activeCampus == null;
    bool showPlaceholder = isOffCampus || (_gpsPermissionDenied && !_hasPoint);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Kies Ligging"),
        actions: [
          if (_hasPoint && !_isSnapping && !isOffCampus)
            IconButton(icon: const Icon(Icons.check, color: AppColors.gold), onPressed: _confirmLocation),
          
          if (_gpsPermissionDenied || isOffCampus)
            IconButton(icon: const Icon(Icons.refresh, color: AppColors.gold), onPressed: _initGps)
          else
            IconButton(
              icon: Icon(_isManualMode ? Icons.location_disabled : Icons.my_location, 
                color: _isManualMode ? Colors.grey : AppColors.gold),
              onPressed: () {
                setState(() => _isManualMode = !_isManualMode);
                if (!_isManualMode) _initGps();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 15),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: !_gpsPermissionDenied,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.hybrid,
            markers: {
              Marker(
                markerId: const MarkerId("selected"),
                position: _selectedLocation,
              )
            },
            circles: CampusService.campusesNotifier.value.map((c) => Circle(
              circleId: CircleId(c.id),
              center: LatLng(c.location.latitude, c.location.longitude),
              radius: c.radius,
              fillColor: AppColors.gold.withValues(alpha: 0.2),
              strokeColor: AppColors.gold,
              strokeWidth: 2,
            )).toSet(),
            onTap: (pos) {
              setState(() {
                _selectedLocation = pos;
                _updateActiveCampus(pos);
              });
            },
          ),

          if (showPlaceholder) 
            _buildNoGpsPlaceholder(
              title: isOffCampus ? "Toegang Geweier" : "Geen GPS Toegang",
              message: isOffCampus 
                ? "Jy moet fisies op 'n Akademia kampus wees om 'n verslag in te dien."
                : "Aktiveer jou GPS om voort te gaan.",
              allowManual: !isOffCampus
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
                    Text("Ligging word vasgelê...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          _buildStatusOverlay(isOffCampus),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay(bool isOffCampus) {
    return Positioned(
      top: 15, left: 15, right: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 230/255), borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 30/255), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(
              isOffCampus ? Icons.block : (_gpsPermissionDenied ? Icons.location_off : (_isManualMode ? Icons.edit_location_alt : Icons.gps_fixed)), 
              size: 16, 
              color: (isOffCampus || _gpsPermissionDenied) ? Colors.red : (_isManualMode ? Colors.orange : AppColors.navy)
            ),
            const SizedBox(width: 10),
            Text(
              isOffCampus ? "GEBLOKKEER" : (_gpsPermissionDenied ? "Geen GPS" : (_isManualMode ? "Handmatige Modus" : "GPS Aktief")), 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.navy)
            ),
            const Spacer(),
            Text(
              _activeCampus?.name ?? (isOffCampus ? "Buite Gebied" : "Soek..."), 
              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoGpsPlaceholder({required String title, required String message, bool allowManual = true}) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            allowManual ? Icons.location_off_outlined : Icons.block_outlined, 
            size: 100, 
            color: allowManual ? AppColors.navy.withValues(alpha: 50/255) : Colors.red.withValues(alpha: 50/255)
          ),
          const SizedBox(height: 25),
          Text(title, style: TextStyle(color: allowManual ? AppColors.navy : Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
