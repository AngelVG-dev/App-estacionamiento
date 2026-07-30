import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import '../services/db_local.dart';
import '../services/location_service.dart';
import '../services/geofence_manager.dart';
import '../services/map_cache_service.dart'; 
import '../services/permission_manager.dart'; 
import '../models/location_model.dart';
import '../widgets/modern_dialogs.dart'; 
import 'map_screen.dart';
import 'login_screen.dart'; 

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({required this.toggleTheme, Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isSaving = false;

  Future<void> saveLocation() async {
    
    bool? understood = await ModernDialogs.showConfirmDialog(
      context: context,
      title: "Uso de Ubicación",
      content: "Para que la alarma de 10 metros funcione, Buscamicoche recopila datos de tu ubicación INCLUSO cuando la app está cerrada o en segundo plano. ¿Aceptas continuar?",
      confirmText: "Entendido",
      icon: Icons.privacy_tip_rounded,
      color: Colors.orange,
    );

    if (understood != true) return; 

    // Pedir permisos
    bool granted = await PermissionManager.requestAllRequiredPermissions(context);
    if (!mounted) return; 
    if (!granted) {
      _showSnackBar("⚠️ Por favor enciende el GPS y acepta los permisos.", Colors.redAccent);
      return;
    }

    bool? wantsPhoto = await ModernDialogs.showConfirmDialog(
      context: context,
      title: "Foto de Referencia",
      content: "¿Deseas agregar una foto del lugar donde te estacionaste? (Es opcional)",
      confirmText: "Tomar Foto",
      icon: Icons.camera_alt_rounded,
      color: Colors.blueAccent,
    );

    if (!mounted) return; 

    String? finalImagePath;

    if (wantsPhoto == true) {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera, 
        imageQuality: 70
      );
      
      if (!mounted) return; 
      finalImagePath = photo?.path;
    }

    bool? guardarOnline = await ModernDialogs.showSelectSourceDialog(
      context: context,
      title: "Guardar Datos",
      content: "¿Quieres respaldar la ubicación en la Nube o solo en este celular?",
      icon: Icons.add_location_alt_rounded,
      color: const Color(0xFF3B82F6),
    );

    if (!mounted) return; 
    if (guardarOnline == null) return; 

    setState(() => isSaving = true);
    _showSnackBar("Buscando satélites... 🛰️", Colors.blueGrey);

    Position? pos = await LocationService.getLocation();
    
    if (!mounted) return; 
    
    if (pos != null) {
      await DBLocal.insert(
        pos.latitude, 
        pos.longitude, 
        online: guardarOnline,
        imagePath: finalImagePath 
      );
      
      await GeofenceManager.startGeofence(pos.latitude, pos.longitude);

      if (mounted) {
        _showSnackBar(
          guardarOnline 
            ? "📍 Guardado en la Nube y Alarma activada" 
            : "📍 Guardado Local y Alarma activada",
          Colors.green
        );
      }
    } else {
      if (mounted) _showSnackBar("❌ No se pudo obtener la ubicación.", Colors.red);
    }
    
    if (mounted) setState(() => isSaving = false);
  }

  Future<void> viewMap() async {
    bool? leerOnline = await ModernDialogs.showSelectSourceDialog(
      context: context,
      title: "Rastrear Vehículo",
      content: "¿Tu coche está guardado en la memoria Local o en la Nube?",
      icon: Icons.travel_explore_rounded,
      color: const Color(0xFF10B981),
    );

    if (!mounted) return; 
    if (leerOnline == null) return; 

    bool useOfflineMap = false;

    if (leerOnline == false) { 
      bool hasCar = await DBLocal.hasLocalCar(); 
      bool hasMaps = await MapCacheService.hasOfflineMaps(); 

      if (hasCar && hasMaps) {
        if (!mounted) return;
        
        bool? wantsOffline = await ModernDialogs.showConfirmDialog(
          context: context,
          title: "Mapa Sin Conexión",
          content: "Hemos detectado que tienes mapas de esta zona descargados. ¿Deseas usarlos para no gastar tus datos móviles?",
          confirmText: "Usar Mapa Descargado",
          icon: Icons.signal_wifi_off,
          color: Colors.green,
        );
        
        if (wantsOffline == true) {
          useOfflineMap = true;
        }
      }
    }

    LocationModel? car = await DBLocal.getLast(online: leerOnline);

    if (!mounted) return; 

    if (car == null) {
      _showSnackBar("🚗 No se encontró ningún vehículo guardado ahí.", Colors.orange);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          carLat: car.latitude, 
          carLng: car.longitude,
          carImagePath: car.imagePath, 
          useOfflineMap: useOfflineMap,
        ),
      ),
    );
  }

  void _showSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6), 
            onPressed: widget.toggleTheme
          )
        ],
      ),


      floatingActionButton: FloatingActionButton(
        heroTag: "btn_logout",
        backgroundColor: Colors.redAccent,
        tooltip: "Cerrar Sesión",
        onPressed: () async {
          final confirm = await ModernDialogs.showConfirmDialog(
            context: context,
            title: "Cerrar Sesión",
            content: "¿Estás seguro de que deseas salir de tu cuenta?",
            confirmText: "Salir",
            icon: Icons.logout,
            color: Colors.redAccent,
          );
          
          if (confirm == true) {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme)),
            );
          }
        },
        child: const Icon(Icons.power_settings_new, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                child: Text(
                  "¿Qué haremos hoy?",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    FadeInLeft(
                      duration: const Duration(milliseconds: 600),
                      child: _ActionCard(
                        title: "Estacionar Vehículo",
                        subtitle: "Usa el GPS (Foto opcional)",
                        icon: Icons.local_parking_rounded,
                        gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        isLoading: isSaving,
                        onTap: saveLocation,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeInRight(
                      duration: const Duration(milliseconds: 600),
                      child: _ActionCard(
                        title: "Rastrear Vehículo",
                        subtitle: "Ver ruta al coche guardado",
                        icon: Icons.explore_rounded,
                        gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
                        isLoading: false,
                        onTap: viewMap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

///  Widget
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title, 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle, 
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}