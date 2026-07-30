import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/modern_dialogs.dart'; 

class PermissionManager {
  
  static Future<bool> requestAllRequiredPermissions(BuildContext context) async {
    bool notifsGranted = await _requestNotifications(context);
    if (!notifsGranted) return false;
    if (!context.mounted) return false;

    bool foregroundGranted = await _requestForegroundLocation(context);
    if (!foregroundGranted) return false;
    if (!context.mounted) return false;

    bool backgroundGranted = await _requestBackgroundLocation(context);
    if (!backgroundGranted) return false;
    if (!context.mounted) return false;

    await _requestBatteryOptimization(context);

    return true;
  }

  static Future<bool> _requestNotifications(BuildContext context) async {
    var status = await Permission.notification.status;
    if (status.isGranted) return true;

    status = await Permission.notification.request();
    
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(
        context,
        "Permiso de Notificaciones",
        "Necesitamos enviarte alertas para avisarte cuando estés a 10 metros de tu coche. Por favor, actívalas en la configuración.",
      );
      return false;
    }
    return status.isGranted;
  }

  static Future<bool> _requestForegroundLocation(BuildContext context) async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;

    status = await Permission.locationWhenInUse.request();

    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(
        context,
        "Ubicación Requerida",
        "El GPS es indispensable para guardar la ubicación del coche. Por favor, permite el acceso en la configuración.",
      );
      return false;
    }
    return status.isGranted;
  }

  static Future<bool> _requestBackgroundLocation(BuildContext context) async {
    var status = await Permission.locationAlways.status;
    if (status.isGranted) return true;

    bool? userAgrees = await ModernDialogs.showConfirmDialog(
      context: context,
      title: "Rastreo en Segundo Plano",
      content: "Para avisarte que llegaste a tu coche INCLUSO si tienes el teléfono guardado y la pantalla apagada, necesitamos acceso a tu ubicación 'Todo el tiempo'. ¿Estás de acuerdo?",
      confirmText: "Permitir Todo el Tiempo",
      icon: Icons.radar,
      color: Colors.blueAccent,
    );

    if (userAgrees != true) return false;

    status = await Permission.locationAlways.request();

    if (status.isPermanentlyDenied || status.isDenied) {
      if (context.mounted) {
        await _showSettingsDialog(
          context,
          "Ubicación Todo el Tiempo",
          "Para la alarma de proximidad (10 metros) en segundo plano, debes seleccionar 'Permitir todo el tiempo' en los ajustes de la app.",
        );
      }
      return false;
    }

    return status.isGranted;
  }

  static Future<void> _requestBatteryOptimization(BuildContext context) async {
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      bool? userAgrees = await ModernDialogs.showConfirmDialog(
        context: context,
        title: "Evitar que la App se cierre",
        content: "Para que el GPS no se apague mientras caminas, necesitamos excluir la app del ahorro de batería. ¿Aceptas?",
        confirmText: "Permitir",
        icon: Icons.battery_charging_full,
        color: Colors.green,
      );

      if (userAgrees == true) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  static Future<void> _showSettingsDialog(BuildContext context, String title, String message) async {
    bool? goToSettings = await ModernDialogs.showConfirmDialog(
      context: context,
      title: title,
      content: message,
      confirmText: "Abrir Configuración",
      icon: Icons.settings,
      color: Colors.orange,
    );

    if (goToSettings == true) {
      await openAppSettings();
    }
  }

  static Future<bool> hasAllPermissions() async {
    return await Permission.notification.isGranted &&
           await Permission.locationWhenInUse.isGranted &&
           await Permission.locationAlways.isGranted;
  }
}