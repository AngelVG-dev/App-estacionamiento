import 'dart:io';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Comparte la ubicación del coche y, la foto
  static Future<void> shareCarLocation({
    required double lat,
    required double lng,
    String? imagePath,
  }) async {
    // 1. Generamos el enlace oficial de Google Maps con las coordenadas exactas
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    // 2. Armamos el mensaje de texto que acompañará al enlace
    final String message = '🚗 ¡Hola! He estacionado mi coche aquí:\n$googleMapsUrl\n\n(Enviado desde mi App de Rastreo)';

    try {
      // 3. Verificamos si el usuario tomó una foto y si el archivo físico existe en su celular
      if (imagePath != null && !imagePath.startsWith('http') && File(imagePath).existsSync()) {
        
        // Compartir el mensaje de texto junto con la imagen
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: message,
          subject: 'Ubicación de mi coche',
        );
        
      } else {
        // 4. Si no hay foto local, simplemente compartimos el texto con el enlace
        await Share.share(
          message,
          subject: 'Ubicación de mi coche',
        );
      }
    } catch (e) {
      print("Error al abrir el menú de compartir: $e");
    }
  }
}