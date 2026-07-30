import 'package:latlong2/latlong.dart';

class LocationModel {
  final double latitude;
  final double longitude;
  final String? imagePath;
  final bool isActive;
  final DateTime createdAt;
  final bool isCloud; 

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.imagePath,
    this.isActive = true,
    required this.createdAt,
    this.isCloud = false, 
  });

  LatLng get toLatLng => LatLng(latitude, longitude);

 
  factory LocationModel.fromMap(Map<String, dynamic> map, {bool isCloud = false}) {
    return LocationModel(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      imagePath: map['image_url'], 
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
      isCloud: isCloud, 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imagePath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}