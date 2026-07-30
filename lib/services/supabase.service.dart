import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // Subimos la foto del coche y devuelve el link público
  static Future<String?> uploadCarPhoto(File imageFile) async {
    try {
      final String fileName = 'car_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _client.storage.from('car_photos').upload(fileName, imageFile);
      
      // Obtenemos la URL para guardarla en la tabla
      return _client.storage.from('car_photos').getPublicUrl(fileName);
    } catch (e) {
      print('Error al subir foto: $e');
      return null;
    }
  }

  /// Guardamos la ubicación en la tabla 'locations'
  static Future<void> saveCarLocation(double lat, double lon, String? imageUrl) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // Requiere estar logueado

    // 1. Desactivamos los carros anteriores (para que solo haya uno 'activo')
    await _client.from('locations')
        .update({'is_active': false})
        .eq('user_id', userId);

    // 2. Insertamos la nueva ubicación
    await _client.from('locations').insert({
      'user_id': userId,
      'latitude': lat,
      'longitude': lon,
      'image_url': imageUrl,
      'is_active': true,
    });
  }

  // Recuperamos el carro activo de la base de datos (por si reinstalan la app)
  static Future<Map<String, dynamic>?> getActiveCarLocation() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client.from('locations')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle(); 

    return response;
  }
}