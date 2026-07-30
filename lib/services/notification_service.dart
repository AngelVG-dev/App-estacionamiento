import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'geofence_manager.dart'; 


@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  print("🔔 Notificación tocada en background. Apagando alarma...");
  bool? hasVibrator = await Vibration.hasVibrator();
  if (hasVibrator == true) {
    Vibration.cancel();
  }
  await GeofenceManager.stopGeofence(); 
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const int _proximityNotificationId = 888; 
  static Timer? _autoCancelTimer; 

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    //Configuracions de las acciones para cuando el usuario toca la notificación
    await _notificationsPlugin.initialize(
      settings,
      //Cuando tocan la alerta con la app abierta (Primer plano)
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print("🔔 Notificación tocada en primer plano. Apagando alarma...");
        await _cancelAlarmFeatures();
      },
      //Cuando tocan la alerta con la app cerrada (Segundo plano)
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Solicitar permisos obligatorios para Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Crear el "Canal" de notificaciones explícitamente en el sistema
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'alarma_coche_id', 
      'Proximidad del Vehículo',
      description: 'Notifica cuando estás a menos de 15 metros de tu coche', //Actualizamos a 15 metros
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Se lanza la alerta
  static Future<void> showCarProximityAlert() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarma_coche_id', 
      'Proximidad del Vehículo',
      channelDescription: 'Notifica cuando estás a menos de 15 metros de tu coche',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true, 
      visibility: NotificationVisibility.public, 
      autoCancel: true, 
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // 1. Mostrar la Notificación
    await _notificationsPlugin.show(
      _proximityNotificationId, 
      '¡Has llegado! 🚗',
      'Tu vehículo está a menos de 15 metros. Toca para apagar la alarma.',
      platformDetails,
    );

    // 2. Iniciar el timbrado 
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000, 500, 1000]); 
    }

    // Cancelamos el timer anterior por si se acumuló uno
    _autoCancelTimer?.cancel();

    // A Los 7 segundos (Sigue funcionando por si se te olvida tocarla)
    _autoCancelTimer = Timer(const Duration(seconds: 7), () async {
      await _cancelAlarmFeatures();
    });
  }

  static Future<void> _cancelAlarmFeatures() async {
    // Ocultamos la notificación
    await _notificationsPlugin.cancel(_proximityNotificationId);
    
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.cancel();
    }
    
    await GeofenceManager.stopGeofence();
  }
}