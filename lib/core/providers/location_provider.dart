import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';

class UserLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String state;
  final String city;
  final String displayState;
  final String displayCity;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.state = 'Delhi',
    this.city = 'Delhi',
    this.displayState = 'Delhi',
    this.displayCity = 'Delhi',
  });

  factory UserLocation.initial() => UserLocation(
        latitude: 28.7041,
        longitude: 77.1025,
        address: 'Fetching location...',
        state: 'Delhi',
        city: 'Delhi',
        displayState: 'Delhi',
        displayCity: 'Delhi',
      );

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? state,
    String? city,
    String? displayState,
    String? displayCity,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      state: state ?? this.state,
      city: city ?? this.city,
      displayState: displayState ?? this.displayState,
      displayCity: displayCity ?? this.displayCity,
    );
  }
}

class LocationNotifier extends StateNotifier<UserLocation> {
  LocationNotifier() : super(UserLocation.initial()) {
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(address: 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(address: 'Location permission denied');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Unknown Location';
      String cityName = 'Delhi';
      String stateName = 'Delhi';
      
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        cityName = p.locality ?? 'Delhi';
        stateName = p.administrativeArea ?? 'Delhi';
        
        address = '$cityName, $stateName';

        state = UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          city: cityName, 
          state: stateName, 
          displayCity: cityName,
          displayState: stateName,
        );
      }
    } catch (e) {
      state = state.copyWith(address: 'Error fetching location');
    }
  }

  void setManualLocation(String address, double lat, double lon, String stateName, String cityName) {
    state = UserLocation(
      latitude: lat,
      longitude: lon,
      address: address,
      state: stateName,
      city: cityName,
      displayState: stateName,
      displayCity: cityName,
    );
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, UserLocation>((ref) {
  return LocationNotifier();
});

final dashboardLocationProvider = FutureProvider<Map<String, String>>((ref) async {
  final loc = ref.watch(locationProvider);
  ref.watch(settingsProvider); // Force rebuild when settings change

  final translatedCity = await LanguageHelper.translate(loc.city, loc.state, loc.city);
  final translatedState = await LanguageHelper.translate(loc.state, loc.state, loc.city);

  return {
    'city': loc.city,
    'state': loc.state,
    'displayCity': translatedCity,
    'displayState': translatedState,
    'lat': loc.latitude.toString(),
    'lng': loc.longitude.toString(),
  };
});

