import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/location_model.dart';

class DBLocal {
  static Database? _database;
  
  static const String supabaseTableName = 'car_locations';
  static const String bucketName = 'car_images';

  static Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'car_locations.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE locations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            image_url TEXT,
            is_active INTEGER,
            created_at TEXT
          )
        ''');
      },
    );
  }

  static Future<String> _saveFilePermanently(String imagePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = basename(imagePath);
    final savedImage = await File(imagePath).copy('${directory.path}/$fileName');
    return savedImage.path;
  }

  static Future<void> insert(double lat, double lng, {String? imagePath, bool online = false}) async {
    String? finalImagePath;

    if (imagePath != null) {
      finalImagePath = await _saveFilePermanently(imagePath);
    }

    if (online) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return; 

        String? cloudRelativePath;
        if (finalImagePath != null) {
          cloudRelativePath = '${user.id}/${basename(finalImagePath)}';
          await Supabase.instance.client.storage
              .from(bucketName)
              .upload(cloudRelativePath, File(finalImagePath));
        }

        await Supabase.instance.client.from(supabaseTableName).insert({
          'latitude': lat,
          'longitude': lng,
          'user_id': user.id,
          'image_url': cloudRelativePath,
        });

      } catch (e) {
        print("❌ ERROR al guardar en Supabase: $e");
      }
    } else {
      final database = await db;
      await database.update('locations', {'is_active': 0}, where: 'is_active = 1');

      final locLocal = LocationModel(
        latitude: lat,
        longitude: lng,
        imagePath: finalImagePath, 
        createdAt: DateTime.now(),
        isCloud: false,
      );
      
      await database.insert('locations', locLocal.toMap());
    }
  }

  static Future<LocationModel?> getLast({bool online = false}) async {
    if (online) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return null;

        final response = await Supabase.instance.client
            .from(supabaseTableName)
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1);

        if (response.isEmpty) return null;

        final data = response.first;
        if (data['image_url'] != null) {
          data['image_url'] = Supabase.instance.client.storage
              .from(bucketName)
              .getPublicUrl(data['image_url']);
        }
        return LocationModel.fromMap(data, isCloud: true); 
      } catch (e) {
        return null;
      }
    } else {
      final database = await db;
      final List<Map<String, dynamic>> maps = await database.query(
        'locations',
        where: 'is_active = 1',
        orderBy: 'id DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return LocationModel.fromMap(maps.first, isCloud: false); 
      }
      return null;
    }
  }

  static Future<List<LocationModel>> getHistory({bool online = true}) async {
    List<LocationModel> unifiedHistory = [];

    try {
      final database = await db;
      final List<Map<String, dynamic>> maps = await database.query('locations', orderBy: 'id DESC');
      unifiedHistory.addAll(maps.map((data) => LocationModel.fromMap(data, isCloud: false)));
    } catch (e) {
      print("❌ ERROR al obtener historial local: $e");
    }

    if (online) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final response = await Supabase.instance.client
              .from(supabaseTableName)
              .select()
              .eq('user_id', user.id)
              .order('created_at', ascending: false);

          final cloudList = response.map((data) {
            if (data['image_url'] != null) {
              data['image_url'] = Supabase.instance.client.storage
                  .from(bucketName)
                  .getPublicUrl(data['image_url']);
            }
            return LocationModel.fromMap(data, isCloud: true);
          }).toList();

          unifiedHistory.addAll(cloudList);
        }
      } catch (e) {
        print("❌ ERROR al obtener historial de la nube: $e");
      }
    }

    unifiedHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return unifiedHistory;
  }

  static Future<bool> hasLocalCar() async {
    final database = await db;
    final count = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM locations WHERE is_active = 1')
    );
    return count != null && count > 0;
  }
}