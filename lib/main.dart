import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/geofence_manager.dart'; 
import 'services/notification_service.dart'; 
import 'services/map_cache_service.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Encender motores de Mapas Offline
  await FMTCObjectBoxBackend().initialise();
  await MapCacheService.initStore(); 
  
  // Servicios de alarma
  await NotificationService.init(); 
  await GeofenceManager.init();    

  runApp(const BuscaMiCocheApp());
}

class BuscaMiCocheApp extends StatefulWidget {
  const BuscaMiCocheApp({Key? key}) : super(key: key);

  @override
  State<BuscaMiCocheApp> createState() => _BuscaMiCocheAppState();
}

class _BuscaMiCocheAppState extends State<BuscaMiCocheApp> {
  ThemeMode themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Busca Mi Coche',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      // 🔥 Ahora iniciamos en el Splash Screen en lugar del Login directo
      home: SplashScreen(toggleTheme: toggleTheme), 
    );
  }
}

/// witdget de pantalla de carga con splash
class SplashScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const SplashScreen({required this.toggleTheme, Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    // Leemos qué decidió el usuario en su último login
    final prefs = await SharedPreferences.getInstance();
    final bool keepSession = prefs.getBool('keep_session') ?? true;
    final supabase = Supabase.instance.client;

    // Preguntamos si quieren mantener abierta sino mandamos a cerrar la sesion
    if (!keepSession) {
      await supabase.auth.signOut();
    }

    // Pequeña pausa para que se vea la pantalla de carga (
    await Future.delayed(const Duration(milliseconds: 800));

    // Revisamos si hay una sesión activa
    final session = supabase.auth.currentSession;

    if (mounted) {
      if (session != null && keepSession) {
        // Tiene token y quiere mantener sesión -> Pasa directo
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme)),
        );
      } else {
        // No tiene token o pidió no guardar sesión -> Va al Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.satellite_alt_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}