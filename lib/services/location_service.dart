import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Solicita permisos de gps escalado
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Obtiene la coordenada exacta
  static Future<Position?> getLocation() async {
    if (!await requestPermission()) return null;
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }


  static Stream<Position> getStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    );
  }

  
  static Future<List<LatLng>> getOSRMRoute(LatLng start, LatLng end) async {

    final url = 'https://router.project-osrm.org/route/v1/foot/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=simplified&geometries=geojson';
    
    try {

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
  
        return coords.map((c) => LatLng(c[1], c[0])).toList(); 
      }
    } catch (e) {
      print("⚠️ Servidor OSRM lento o sin red: $e");

      return []; 
    }

    return [];
  }
}