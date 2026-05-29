import 'package:flutter/material.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';
import 'package:bharat_flow/features/profile/data/repositories/profile_repository.dart';

class MapRegion {
  final String id;
  final String name;
  final String size;
  final String imageUrl;
  bool isDownloaded;
  bool isDownloading;
  double progress;
  DateTime? downloadDate;

  MapRegion({
    required this.id,
    required this.name,
    required this.size,
    required this.imageUrl,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.progress = 0.0,
    this.downloadDate,
  });
}

class OfflineMapsScreen extends ConsumerStatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  ConsumerState<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends ConsumerState<OfflineMapsScreen> {
  List<MapRegion> _downloadedMaps = [];

  final double _totalStorage = 128.0; // GB
  double _usedStorage = 42.5; // GB
  
  // Map State
  final MapController _mapController = MapController();
  String _currentRegionName = "Locating...";
  bool _isLocating = false;
  Timer? _debounceTimer;
  bool _isDownloadingMap = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavedMaps();
    _getCurrentLocation();
  }

  void _loadSavedMaps() {
    final box = Hive.box('offline_maps');
    final List? savedData = box.get('maps');
    if (savedData != null) {
      setState(() {
        _downloadedMaps = savedData.map((m) => MapRegion(
          id: m['id'],
          name: m['name'],
          size: m['size'],
          imageUrl: m['imageUrl'] ?? '',
          isDownloaded: true,
          downloadDate: DateTime.parse(m['date']),
        )).toList();
        _usedStorage = 42.5 + (_downloadedMaps.length * 0.25);
      });
    }
  }

  void _saveMapsToHive() {
    final box = Hive.box('offline_maps');
    final dataToSave = _downloadedMaps.map((m) => {
      'id': m.id,
      'name': m.name,
      'size': m.size,
      'imageUrl': m.imageUrl,
      'date': m.downloadDate?.toIso8601String(),
    }).toList();
    box.put('maps', dataToSave);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateRegionName(const LatLng(28.6139, 77.2090));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateRegionName(const LatLng(28.6139, 77.2090));
          return;
        }
      }
      
      Position position = await Geolocator.getCurrentPosition();
      final currentLatLng = LatLng(position.latitude, position.longitude);
      
      if (!mounted) return;
      _mapController.move(currentLatLng, 12.0);
      _updateRegionName(currentLatLng);
    } catch (e) {
      _updateRegionName(const LatLng(28.6139, 77.2090));
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _updateRegionName(LatLng center) async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      setState(() => _isLocating = true);
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(center.latitude, center.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          setState(() {
            _currentRegionName = "${place.subAdministrativeArea ?? place.locality ?? 'Unknown'}, ${place.administrativeArea ?? ''}";
            _isLocating = false;
          });
        }
      } catch (e) {
        setState(() {
          _currentRegionName = "Select Region";
          _isLocating = false;
        });
      }
    });
  }

  void _downloadCurrentRegion() async {
    setState(() {
      _isDownloadingMap = true;
      _downloadProgress = 0.0;
    });

    // Simulate download progress
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _downloadProgress = i / 100;
      });
    }

    // Actual Data Sync
    try {
      final parts = _currentRegionName.split(',');
      final city = parts.isNotEmpty ? parts[0].trim() : null;
      final state = parts.length > 1 ? parts[1].trim() : null;
      
      await MandiRepository().performSilentLocalSync(
        userState: state,
        userCity: city,
      );
    } catch (e) {
      debugPrint("Data sync error: $e");
    }

    if (!mounted) return;
    
    final newMap = MapRegion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _currentRegionName,
      size: _getEstimatedSize(),
      imageUrl: '',
      isDownloaded: true,
      downloadDate: DateTime.now(),
    );

    setState(() {
      _isDownloadingMap = false;
      _downloadedMaps.insert(0, newMap);
      _usedStorage += 0.25; 
      _saveMapsToHive(); // Save to Hive
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newMap.name} saved for offline use!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getEstimatedSize() {
    try {
      double zoom = _mapController.camera.zoom;
      // Heuristic: More zoom = more detail = more size
      double baseSize = 150.0; 
      double multiplier = (20 - zoom).abs() * 25.0;
      double finalSize = baseSize + multiplier;
      
      if (finalSize > 1024) {
        return "${(finalSize / 1024).toStringAsFixed(1)} GB";
      }
      return "${finalSize.toStringAsFixed(0)} MB";
    } catch (_) {
      return "250 MB";
    }
  }

  String _getVisibleRangeKm() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      final west = bounds.west;
      final east = bounds.east;
      final center = _mapController.camera.center;
      
      const distance = Distance();
      final km = distance.as(
        LengthUnit.Kilometer,
        LatLng(center.latitude, west),
        LatLng(center.latitude, east),
      );
      
      return "${km.toStringAsFixed(0)} KM";
    } catch (_) {
      return "--- KM";
    }
  }

  void _deleteMap(MapRegion map) {
    setState(() {
      _downloadedMaps.removeWhere((m) => m.id == map.id);
      _usedStorage -= 0.25;
      _saveMapsToHive(); // Update Hive
    });
  }

  void _refreshMap(MapRegion map) async {
    // Just a quick visual refresh for now
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updating ${map.name}...'), duration: const Duration(seconds: 1)),
    );
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      map.downloadDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;
    final googleUser = googleUserAsync.value;
    final authUser = Supabase.instance.client.auth.currentUser;
    final box = Hive.box('settings');

    final String? photoUrl = profile?.avatarUrl ??
        googleUser?.photoUrl ??
        authUser?.userMetadata?['avatar_url'] ??
        authUser?.userMetadata?['picture'] ??
        box.get('userPhoto');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildTopAppBar(context, photoUrl),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStorageCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Download New Region'),
                const SizedBox(height: 12),
                _buildInteractiveMap(),
                const SizedBox(height: 16),
                const DynamicAdmobCardWidget(),
                const SizedBox(height: 24),
                _buildSectionTitle('Downloaded Maps'),
                const SizedBox(height: 12),
                if (_downloadedMaps.isEmpty)
                  _buildEmptyState()
                else
                  ..._downloadedMaps.map((map) => _buildDownloadedItem(map)),
                const SizedBox(height: 24),
                _buildHintSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, String? photoUrl) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      centerTitle: false,
      title: const Text(
        'Offline Maps',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          letterSpacing: -0.5,
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.primaryColor),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Hero(
            tag: 'profile_photo',
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 2),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person, size: 18, color: AppTheme.primaryColor) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageCard() {
    double usagePercent = _usedStorage / _totalStorage;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STORAGE USAGE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
              // Removed storage icon
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_usedStorage.toStringAsFixed(1)} GB',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ ${_totalStorage.toStringAsFixed(0)} GB',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                height: 10,
                width: (MediaQuery.of(context).size.width - 80) * usagePercent,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(usagePercent * 100).toStringAsFixed(0)}% Used',
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(_totalStorage - _usedStorage).toStringAsFixed(1)} GB Available',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppTheme.primaryColor,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildInteractiveMap() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(28.6139, 77.2090),
              initialZoom: 5.0, // Zoomed out to see more area (states/zones)
              minZoom: 3.0,     // Allows zooming out to see the whole of India
              maxZoom: 18.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && pos.center != null) {
                  _updateRegionName(pos.center!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bharatflow.app',
              ),
              Center(
                child: Icon(Icons.location_on, color: AppTheme.primaryColor, size: 30),
              ),
            ],
          ),
          // Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLocating ? "Detecting..." : _currentRegionName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Coverage: ${_getVisibleRangeKm()} • Est. Size: ${_getEstimatedSize()}",
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (!_isDownloadingMap)
                        ElevatedButton(
                          onPressed: _downloadCurrentRegion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('DOWNLOAD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isDownloadingMap)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: _downloadProgress,
                              strokeWidth: 8,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                            Center(
                              child: Text(
                                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Optimizing Offline Map Data...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  Widget _buildDownloadedItem(MapRegion map) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.map_rounded, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(map.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${map.size} • Updated ${map.downloadDate != null ? DateFormat('dd MMM').format(map.downloadDate!) : "Just now"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 10, color: Colors.green),
                      SizedBox(width: 4),
                      Text("Offline Data Active", style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _refreshMap(map),
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.blueGrey),
                tooltip: 'Update',
              ),
              IconButton(
                onPressed: () => _deleteMap(map),
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.map_outlined, size: 48, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'No maps downloaded yet',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildHintSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF2E7D32), size: 22),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Offline maps allow you to access mandi prices and weather data without an active internet connection. Move the map above to select your area and tap Download.',
              style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
