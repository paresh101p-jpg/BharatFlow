import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/providers/location_provider.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/services/notification_service.dart';
import 'mera_khet_dashboard.dart';

class MeraKhetHome extends ConsumerStatefulWidget {
  final String cropName;
  final DateTime sowingDate;
  
  const MeraKhetHome({
    Key? key,
    required this.cropName,
    required this.sowingDate,
  }) : super(key: key);

  @override
  ConsumerState<MeraKhetHome> createState() => _MeraKhetHomeState();
}

class _MeraKhetHomeState extends ConsumerState<MeraKhetHome> {
  GoogleMapController? _mapController;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polygonPoints = [];
  
  double _areaInAcres = 0.0;
  double _areaInBigha = 0.0;
  double _areaInHectare = 0.0;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _handleTap(LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _updatePolygon();
      _calculateArea();
    });
  }

  void _updatePolygon() {
    _polygons.clear();
    _markers.clear();
    _polylines.clear();
    
    if (_polygonPoints.isNotEmpty) {
      // Add markers for all points so user can see their clicks immediately
      for (int i = 0; i < _polygonPoints.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('point_$i'),
            position: _polygonPoints[i],
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }

      // If only 2 points, draw a line between them
      if (_polygonPoints.length == 2) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('farm_line'),
            points: _polygonPoints,
            color: Colors.orangeAccent,
            width: 4,
          ),
        );
      }

      // If 3 or more points, draw the full shape (Polygon)
      if (_polygonPoints.length >= 3) {
        _polygons.add(
          Polygon(
            polygonId: const PolygonId('farm_boundary'),
            points: _polygonPoints,
            strokeWidth: 4,
            strokeColor: Colors.orangeAccent, // Neon Orange
            fillColor: Colors.greenAccent.withOpacity(0.3), // Neon Green transparent
          ),
        );
      }
    }
  }

  void _calculateArea() {
    if (_polygonPoints.length < 3) {
      _areaInAcres = 0;
      _areaInBigha = 0;
      _areaInHectare = 0;
      return;
    }
    
    // Convert Google Maps LatLng to maps_toolkit LatLng
    List<mp.LatLng> toolkitPoints = _polygonPoints.map((p) => mp.LatLng(p.latitude, p.longitude)).toList();
    
    // Calculate area in square meters
    double areaSqMeters = mp.SphericalUtil.computeArea(toolkitPoints).toDouble();
    
    setState(() {
      _areaInHectare = areaSqMeters / 10000;
      _areaInAcres = areaSqMeters / 4046.86;
      _areaInBigha = _areaInAcres * 2.5; // Gujarat standard approx
    });
  }

  void _clearMap() {
    setState(() {
      _polygonPoints.clear();
      _updatePolygon();
      _calculateArea();
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _updatePolygon();
        _calculateArea();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final userLoc = ref.read(locationProvider);
    final initialPosition = CameraPosition(
      target: LatLng(userLoc.latitude, userLoc.longitude),
      zoom: 17.0, // zoom in close enough to see the farm
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t['mera_khet'] ?? 'Mera Khet', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.satellite,
            initialCameraPosition: initialPosition,
            onMapCreated: _onMapCreated,
            polygons: _polygons,
            markers: _markers,
            polylines: _polylines,
            onTap: _handleTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false, // Hide default zoom controls to avoid overlap
            padding: const EdgeInsets.only(top: 100, bottom: 120), // Adjust default map controls position
          ),
          
          // Premium Area Info Card
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.architecture_rounded, color: Colors.greenAccent, size: 20),
                          SizedBox(width: 8),
                          Text('FARM AREA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.greenAccent, letterSpacing: 1.5)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAreaStat(t['acres'] ?? 'ACRES', _areaInAcres),
                          Container(height: 30, width: 1, color: Colors.white30),
                          _buildAreaStat(t['bigha'] ?? 'BIGHA', _areaInBigha),
                          Container(height: 30, width: 1, color: Colors.white30),
                          _buildAreaStat(t['hectare'] ?? 'HECTARE', _areaInHectare),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Instructional Banner (Only shows when no points are drawn)
          if (_polygonPoints.isEmpty)
            Positioned(
              bottom: 180,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Colors.deepOrange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t['mera_khet_instruction'] ?? 'Khet naapne ke liye, map par apne khet ke chaaron kono (corners) par touch karein 👇',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Premium Drawing Tools
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionBtn(t['undo'] ?? 'Undo', Icons.undo_rounded, _undoLastPoint),
                    _buildActionBtn(t['clear_btn'] ?? 'Clear', Icons.delete_outline_rounded, _clearMap),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: _promptForFarmNameAndSave,
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(t['save_crop_map'] ?? 'Save Crop Map', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAreaStat(String label, double value) {
    return Column(
      children: [
        Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black87, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _promptForFarmNameAndSave() {
    final t = ref.read(translationsProvider);
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t['min_3_points_error'] ?? 'Kripya khet banane ke liye map par kam se kam 3 point lagayen.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _saveCropPatch();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MeraKhetDashboard(farmId: 'crop_patch'),
      ),
    );
  }

  Future<void> _saveCropPatch() async {
    final box = Hive.box('settings');
    List<dynamic> cropPatches = box.get('saved_crop_patches', defaultValue: []) as List<dynamic>;
    
    final pointsList = _polygonPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
    
    // Attempt to reverse geocode the first point for a location name
    String locName = 'My Farm';
    try {
      final p = _polygonPoints.first;
      List<Placemark> placemarks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        locName = '${place.subLocality ?? place.locality}, ${place.administrativeArea}';
      }
    } catch (e) {
      // Ignore
    }

    final newCropPatch = {
      'id': 'patch_${DateTime.now().millisecondsSinceEpoch}',
      'cropName': widget.cropName,
      'sowingDate': widget.sowingDate.toIso8601String(),
      'area': _areaInAcres,
      'points': pointsList,
      'locationName': locName,
    };
    
    cropPatches.add(newCropPatch);
    
    box.put('saved_crop_patches', cropPatches);
    box.put('has_saved_farm', true); // Keep this flag so the app knows user has onboarded

    try {
      NotificationService.scheduleFertilizerAlerts(widget.cropName, widget.sowingDate);
    } catch(e) {}
  }
}
