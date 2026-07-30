import 'dart:async';
import 'package:geofence_service/geofence_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location) async {
  
  if (geofenceStatus == GeofenceStatus.ENTER) {
    try {
      await NotificationService.showCarProximityAlert();
    } catch (e) {
      print("Error al disparar la alarma de proximidad: $e");
    }
  }
}

class GeofenceManager {
  
  static final _geofenceService = GeofenceService.instance.setup(
    interval: 3000,          
    accuracy: 100,           
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 3000, 
    useActivityRecognition: false, 
    allowMockLocations: false,
    printDevLog: false,
  );

  static Future<void> init() async {
    await NotificationService.init();
    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
  }

  static Future<void> startGeofence(double latCarro, double lonCarro) async {
    await _geofenceService.stop();
    _geofenceService.clearGeofenceList();

    final geofence = Geofence(
      id: 'mi_coche_guardado',
      latitude: latCarro,
      longitude: lonCarro,
      radius: [
        GeofenceRadius(id: 'radio_15m', length: 15), 
      ],
    );

    _geofenceService.addGeofence(geofence);
    try {
      await _geofenceService.start();
    } catch (e) {
      print("Error al iniciar el GPS: $e");
    }
  }

  static Future<void> stopGeofence() async {
    await _geofenceService.stop();
    _geofenceService.clearGeofenceList();
  }
}