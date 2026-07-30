import 'dart:convert';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:path_provider/path_provider.dart';

class MapCacheService {
  // Nombre por defecto por si el usuario no escribe nada
  static const String storeName = 'car_offline_map';

  // 🗂️ Lógica para guardar la lista de nombres en el celular
  static Future<File> get _metadataFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/offline_maps_list.json');
  }

  /// 🔍 Obtiene la lista de todos los mapas que hemos descargado
  static Future<List<String>> getSavedMapNames() async {
    try {
      final file = await _metadataFile;
      if (!await file.exists()) {
        // Compatibilidad con tu versión anterior
        final exists = await FMTCStore(storeName).manage.ready;
        if (exists) return [storeName];
        return [];
      }
      final String contents = await file.readAsString();
      return List<String>.from(jsonDecode(contents));
    } catch (e) {
      return [];
    }
  }

  /// 📝 Anota un nuevo mapa en el historial
  static Future<void> _addMapNameToHistory(String name) async {
    final names = await getSavedMapNames();
    if (!names.contains(name)) {
      names.add(name);
      final file = await _metadataFile;
      await file.writeAsString(jsonEncode(names));
    }
  }

  static Future<void> initStore({String customStoreName = storeName}) async {
    final store = FMTCStore(customStoreName);
    final bool exists = await store.manage.ready;
    if (!exists) {
      await store.manage.create();
    }
  }

  static Future<bool> hasOfflineMaps() async {
    final names = await getSavedMapNames();
    return names.isNotEmpty;
  }

  /// 📥 Descarga el área y la guarda con el nombre elegido
  static Stream<DownloadProgress>? downloadVisibleArea({
    required LatLngBounds bounds,
    required int maxZoom,
    required String customStoreName, // 🔥 Recibe el nombre escrito por el usuario
  }) {
    try {
      // Limpiamos el nombre para que la base de datos interna lo acepte sin errores
      final safeStoreName = customStoreName.trim().isEmpty 
          ? storeName 
          : customStoreName.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();

      final store = FMTCStore(safeStoreName);
      final region = RectangleRegion(bounds);
      
      final downloadableRegion = region.toDownloadable(
        minZoom: 13, 
        maxZoom: maxZoom, 
        options: TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'com.buscamicoche.app',
        ),
      );

      // Guardamos el nombre en nuestro historial local
      _addMapNameToHistory(safeStoreName);

      return store.download.startForeground(
        region: downloadableRegion,
        skipExistingTiles: true, 
      );

    } catch (e) {
      print("Error crítico al iniciar la descarga del mapa interactivo: $e");
      return null;
    }
  }
}