import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../services/location_service.dart';
import '../services/map_cache_service.dart';
import '../services/share_service.dart';
import '../services/db_local.dart';
import '../models/location_model.dart';
import '../widgets/progress_card.dart';

class MapScreen extends StatefulWidget {
  final double carLat;
  final double carLng;
  final String? carImagePath;
  final bool useOfflineMap; 

  const MapScreen({
    required this.carLat, 
    required this.carLng, 
    this.carImagePath, 
    this.useOfflineMap = false, 
    Key? key
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  
  late LatLng _carLocation;
  String? _currentCarImagePath;
  LatLng? _targetLocation; 
  
  StreamSubscription<Position>? _positionStream;
  double _distanceToCar = 0.0;

  List<LatLng> _routePoints = [];
  Stream<DownloadProgress>? _downloadStream;
  bool _isDownloading = false;
  
  bool _isRoutingActive = false;
  bool _isFetchingRoute = false; 

  
  bool _isSelectingDownloadArea = false;
  double _downloadAreaRadiusKm = 1.0; 
  LatLngBounds? _previewBounds; 
  
  int _selectedMapMode = 0;
  String _currentOfflineStore = MapCacheService.storeName; 

  @override
  void initState() {
    super.initState();
    _carLocation = LatLng(widget.carLat, widget.carLng);
    _currentCarImagePath = widget.carImagePath;
    
    if (widget.useOfflineMap) {
      _selectedMapMode = 2; 
    }

    _startTracking();

    if (widget.useOfflineMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📡 Modo Offline Activado. Ahorrando datos móviles."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          )
        );
      });
    }
  }

  void _startTracking() async {
    Position? initialPos = await LocationService.getLocation();
    if (initialPos != null && mounted) {
      setState(() {
        _userLocation = LatLng(initialPos.latitude, initialPos.longitude);
        _calculateDistance();
      });
      _fitMapToUserAndCar(); 
    }

    _positionStream = LocationService.getStream().listen((Position position) {
      if (mounted) {
        final newPos = LatLng(position.latitude, position.longitude);
        if (_isRoutingActive && (_userLocation == null || const Distance().as(LengthUnit.Meter, _userLocation!, newPos) > 10)) {
          _updateRoute(newPos);
        }
        setState(() {
          _userLocation = newPos;
          _calculateDistance();
        });
      }
    });
  }

  void _calculateDistance() {
    if (_userLocation != null) {
      _distanceToCar = const Distance().as(LengthUnit.Meter, _userLocation!, _carLocation);
    }
  }

  
  Future<void> _updateRoute(LatLng startPoint) async {
    setState(() => _isFetchingRoute = true); 

    
    bool hasInternet = true;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) hasInternet = false;
    } catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🔌 Sin conexión a internet para calcular la ruta."), backgroundColor: Colors.orange)
        );
        setState(() { _isRoutingActive = false; _isFetchingRoute = false; });
      }
      return;
    }

    try {
      final points = await LocationService.getOSRMRoute(startPoint, _carLocation);
      if (mounted) {
        if (points.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ No se pudo calcular la ruta."), backgroundColor: Colors.orange));
          setState(() { _isRoutingActive = false; _routePoints.clear(); });
        } else {
          setState(() => _routePoints = points);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Error al buscar la ruta."), backgroundColor: Colors.red));
        setState(() => _isRoutingActive = false);
      }
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false); 
    }
  }

  void _fitMapToUserAndCar() {
    if (_userLocation != null) {
      final bounds = LatLngBounds.fromPoints([_userLocation!, _carLocation]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
    } else {
      _mapController.move(_carLocation, 17.0);
    }
  }

  LatLngBounds _getBoundsFromCenterAndRadius(LatLng center, double radiusKm) {
    double latDelta = radiusKm / 111.0;
    double lngDelta = radiusKm / (111.0 * cos(center.latitude * pi / 180.0));
    return LatLngBounds(
      LatLng(center.latitude - latDelta, center.longitude - lngDelta),
      LatLng(center.latitude + latDelta, center.longitude + lngDelta),
    );
  }

  void _showHistoryBottomSheet() {
    bool isOnlineHistory = _selectedMapMode != 2; 

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7, 
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text("Historial de Estacionamiento", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(label: const Text("☁️ Nube (Fusionado)"), selected: isOnlineHistory, onSelected: (val) => setModalState(() => isOnlineHistory = true)),
                  const SizedBox(width: 12),
                  ChoiceChip(label: const Text("📱 Solo Local"), selected: !isOnlineHistory, selectedColor: Colors.green.withOpacity(0.3), onSelected: (val) => setModalState(() => isOnlineHistory = false)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<LocationModel>>(
                  future: DBLocal.getHistory(online: isOnlineHistory), 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text(isOnlineHistory ? "No hay historial disponible." : "No hay historial en este celular."));
                    
                    final history = snapshot.data!;
                    return ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final loc = history[index];
                        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(loc.createdAt.toLocal());
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            

                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (loc.imagePath != null && loc.imagePath!.isNotEmpty)
                                  ? (loc.imagePath!.startsWith('http') 
                                      ? Image.network(loc.imagePath!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.broken_image)))
                                      : Image.file(File(loc.imagePath!), width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.broken_image))))
                                  : Container(width: 60, height: 60, color: Colors.blueAccent.withOpacity(0.2), child: const Icon(Icons.directions_car, color: Colors.blueAccent)),
                            ),
                            

                            title: Row(
                              children: [
                                Expanded(child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: loc.isCloud ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    loc.isCloud ? "☁️ Nube" : "📱 Local",
                                    style: TextStyle(fontSize: 10, color: loc.isCloud ? Colors.blue : Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("Lat: ${loc.latitude.toStringAsFixed(4)}\nLng: ${loc.longitude.toStringAsFixed(4)}"),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: () {
                              setState(() {
                                _carLocation = LatLng(loc.latitude, loc.longitude);
                                _currentCarImagePath = loc.imagePath;
                                _routePoints.clear();
                                _isRoutingActive = false;
                                _calculateDistance();
                                _mapController.move(_carLocation, 17.0);
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfflineMapsHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Icons.download_done, color: Colors.green), SizedBox(width: 10), Text("Mapas Guardados", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))],
            ),
            const SizedBox(height: 16),
            const Text("Selecciona la región que deseas usar sin internet:", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            
            Expanded(
              child: FutureBuilder<List<String>>(
                future: MapCacheService.getSavedMapNames(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No has descargado ningún mapa aún."));
                  
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      String mapName = snapshot.data![index];
                      String displayName = mapName.replaceAll('_', ' ').toUpperCase();

                      return ListTile(
                        leading: const Icon(Icons.map, color: Colors.green),
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: _currentOfflineStore == mapName ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () {
                          setState(() => _currentOfflineStore = mapName);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Cambiaste al mapa: $displayName"), backgroundColor: Colors.green));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapStyleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text("Estilo de Mapa", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(leading: const Icon(Icons.map, color: Colors.blueAccent), title: const Text("Estándar (Requiere Datos)"), trailing: _selectedMapMode == 0 ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null, onTap: () { setState(() => _selectedMapMode = 0); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.satellite_alt, color: Colors.orange), title: const Text("Satélite (Requiere Datos)"), trailing: _selectedMapMode == 1 ? const Icon(Icons.check_circle, color: Colors.orange) : null, onTap: () { setState(() => _selectedMapMode = 1); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.signal_wifi_off, color: Colors.green), title: const Text("Modo Offline (Descargado)"), trailing: _selectedMapMode == 2 ? const Icon(Icons.check_circle, color: Colors.green) : null, onTap: () { setState(() => _selectedMapMode = 2); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }

  void _startDownloadSelection() {
    setState(() {
      _isSelectingDownloadArea = true;
      _previewBounds = _getBoundsFromCenterAndRadius(_mapController.camera.center, _downloadAreaRadiusKm);
    });
  }

  Future<void> _confirmDownloadArea() async {
    setState(() => _isSelectingDownloadArea = false);

    double selectedZoom = 16.0;
    TextEditingController nameController = TextEditingController(); 

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) => FadeInUp(
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(children: [Icon(Icons.save_alt, color: Colors.purpleAccent), SizedBox(width: 10), Text("Guardar Mapa")]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Dale un nombre a esta zona para encontrarla fácilmente.", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "Ej. Centro Histórico",
                      labelText: "Nombre de la Zona",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.purpleAccent)
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Nivel de Zoom: ${selectedZoom.toInt()}"),
                  Slider(value: selectedZoom, min: 14, max: 18, divisions: 4, activeColor: Colors.purpleAccent, label: selectedZoom.toInt().toString(), onChanged: (val) => setStateSB(() => selectedZoom = val)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white), 
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, escribe un nombre."), backgroundColor: Colors.orange));
                    return;
                  }
                  Navigator.pop(context, true);
                }, 
                child: const Text("Descargar")
              ),
            ],
          ),
        )
      )
    );

    if (confirm == true && mounted && _previewBounds != null) {
      final stream = MapCacheService.downloadVisibleArea(
        bounds: _previewBounds!, 
        maxZoom: selectedZoom.toInt(),
        customStoreName: nameController.text 
      );
      
      if (stream != null) {
        setState(() { _downloadStream = stream.asBroadcastStream(); _isDownloading = true; });
        _downloadStream!.listen((_) {}, onDone: () { if (mounted) setState(() { _isDownloading = false; _previewBounds = null; }); }, onError: (e) { if (mounted) setState(() { _isDownloading = false; _previewBounds = null; }); });
      }
    } else {
      setState(() => _previewBounds = null);
    }
  }

  void _showPhotoDialog() {
    if (_currentCarImagePath == null || _currentCarImagePath!.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _currentCarImagePath!.startsWith('http')
                ? Image.network(_currentCarImagePath!, fit: BoxFit.cover)
                : Image.file(File(_currentCarImagePath!), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: CircleAvatar(backgroundColor: isDark ? Colors.black54 : Colors.white70, child: const Icon(Icons.arrow_back)), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_currentCarImagePath != null && _currentCarImagePath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: CircleAvatar(backgroundColor: isDark ? Colors.black54 : Colors.white70, child: const Icon(Icons.camera_alt, color: Colors.blueAccent)),
                onPressed: _showPhotoDialog,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _carLocation,
              initialZoom: 16.0,
              onTap: (tapPos, point) {
                setState(() => _targetLocation = point);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📍 Destino fijado."), duration: Duration(seconds: 2)));
              },
              onPositionChanged: (position, hasGesture) {
                if (_isSelectingDownloadArea && mounted) {
                  setState(() {
                    _previewBounds = _getBoundsFromCenterAndRadius(_mapController.camera.center, _downloadAreaRadiusKm);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _selectedMapMode == 1 ? "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}" : "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.buscamicoche.app',
                tileProvider: FMTCStore(_currentOfflineStore).getTileProvider(settings: FMTCTileProviderSettings(behavior: _selectedMapMode == 2 ? CacheBehavior.cacheOnly : CacheBehavior.cacheFirst)),
              ),
              if (_previewBounds != null) PolygonLayer(polygons: [Polygon(points: [LatLng(_previewBounds!.north, _previewBounds!.west), LatLng(_previewBounds!.north, _previewBounds!.east), LatLng(_previewBounds!.south, _previewBounds!.east), LatLng(_previewBounds!.south, _previewBounds!.west)], color: Colors.purpleAccent.withOpacity(0.3), borderColor: Colors.purpleAccent, borderStrokeWidth: 4)]),
              if (_isRoutingActive) PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5.0, color: Colors.blueAccent)]),
              MarkerLayer(
                markers: [
                  Marker(point: _carLocation, width: 60, height: 60, child: const Icon(Icons.directions_car, color: Colors.redAccent, size: 40)),
                  if (_userLocation != null) Marker(point: _userLocation!, width: 40, height: 40, child: Container(decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]))),
                  if (_targetLocation != null) Marker(point: _targetLocation!, width: 50, height: 50, child: FadeInDown(child: const Icon(Icons.flag, color: Colors.green, size: 45))),
                ],
              ),
            ],
          ),

          if (_isSelectingDownloadArea)
            Positioned(
              bottom: 30, left: 20, right: 20,
              child: FadeInUp(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Mueve el mapa para centrar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text("Tamaño del área: ${_downloadAreaRadiusKm.toStringAsFixed(1)} km", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                        Slider(
                          value: _downloadAreaRadiusKm,
                          min: 0.5,
                          max: 5.0,
                          divisions: 9,
                          activeColor: Colors.purpleAccent,
                          onChanged: (val) {
                            setState(() {
                              _downloadAreaRadiusKm = val;
                              _previewBounds = _getBoundsFromCenterAndRadius(_mapController.camera.center, _downloadAreaRadiusKm);
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(onPressed: () => setState(() { _isSelectingDownloadArea = false; _previewBounds = null; }), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                              icon: const Icon(Icons.check),
                              label: const Text("Confirmar Área"),
                              onPressed: _confirmDownloadArea,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (!_isDownloading && !_isSelectingDownloadArea)
            Positioned(
              right: 16, bottom: 140, 
              child: FadeInRight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(heroTag: "btn_history", mini: true, backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, onPressed: _showHistoryBottomSheet, child: const Icon(Icons.history)),
                    const SizedBox(height: 12),
                    FloatingActionButton(heroTag: "btn_layers", mini: true, backgroundColor: isDark ? Colors.grey[800] : Colors.white, foregroundColor: Colors.orange, onPressed: _showMapStyleSelector, child: const Icon(Icons.layers)),
                    const SizedBox(height: 12),
                    
                    if (_selectedMapMode == 2) ...[
                      FloatingActionButton(heroTag: "btn_offline_maps", mini: true, backgroundColor: Colors.green, foregroundColor: Colors.white, onPressed: _showOfflineMapsHistory, child: const Icon(Icons.snippet_folder)),
                      const SizedBox(height: 12),
                    ],

                    FloatingActionButton(
                      heroTag: "btn_route", mini: true,
                      backgroundColor: _isRoutingActive ? Colors.blueAccent : (isDark ? Colors.grey[800] : Colors.white),
                      foregroundColor: _isRoutingActive ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      onPressed: _isFetchingRoute ? null : () { 
                        if (_userLocation == null) return;
                        setState(() { _isRoutingActive = !_isRoutingActive; if (_isRoutingActive) { _updateRoute(_userLocation!); _fitMapToUserAndCar(); } else { _routePoints.clear(); }});
                      },
                      child: _isFetchingRoute ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)) : const Icon(Icons.route),
                    ),
                    const SizedBox(height: 12),

                    FloatingActionButton(
                      heroTag: "btn_share", mini: true, 
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white, 
                      foregroundColor: Colors.blueAccent, 
                      onPressed: () { ShareService.shareCarLocation(lat: _carLocation.latitude, lng: _carLocation.longitude, imagePath: _currentCarImagePath); }, 
                      child: const Icon(Icons.share)
                    ),
                    const SizedBox(height: 12),

                    FloatingActionButton(heroTag: "btn_download", mini: true, backgroundColor: isDark ? Colors.grey[800] : Colors.white, foregroundColor: Colors.purpleAccent, onPressed: _startDownloadSelection, child: const Icon(Icons.download_for_offline)),
                    const SizedBox(height: 12),
                    FloatingActionButton(heroTag: "btn_car", mini: true, backgroundColor: isDark ? Colors.grey[800] : Colors.white, foregroundColor: Colors.redAccent, onPressed: () => _mapController.move(_carLocation, 18.0), child: const Icon(Icons.directions_car)),
                  ],
                ),
              ),
            ),

          if (!_isDownloading && !_isSelectingDownloadArea)
            Positioned(
              bottom: 40, left: 20, right: 20,
              child: FadeInUp(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text("Distancia al vehículo", style: Theme.of(context).textTheme.bodyMedium), Text("${_distanceToCar.toStringAsFixed(0)} metros", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))]),
                          FloatingActionButton(heroTag: "btn_user", onPressed: () { if (_userLocation != null) _mapController.move(_userLocation!, 18.0); }, backgroundColor: Theme.of(context).colorScheme.primary, child: const Icon(Icons.my_location, color: Colors.white))
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_isDownloading && _downloadStream != null)
            Positioned(bottom: 40, left: 20, right: 20, child: FadeInUp(child: ProgressCard(progressStream: _downloadStream!, onCancel: () { FMTCStore(_currentOfflineStore).download.cancel(); setState(() => _isDownloading = false); }))),
        ],
      ),
    );
  }
}