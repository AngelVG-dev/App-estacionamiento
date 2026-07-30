import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const LoginScreen({required this.toggleTheme, Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final auth = AuthService();
  
  bool isLoading = false;
  bool _keepSession = true; 

  @override
  void initState() {
    super.initState();
    _loadSessionPreference();
  }

  // 🔥 Carga la preferencia si el usuario ya la había seleccionado antes
  Future<void> _loadSessionPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepSession = prefs.getBool('keep_session') ?? true; 
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.satellite_alt_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          "Busca Mi Coche",
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: "Correo electrónico", prefixIcon: Icon(Icons.email_outlined)),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: pass,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock_outline)),
                        ),
                        const SizedBox(height: 15),
                        
                        Row(
                          children: [
                            Checkbox(
                              value: _keepSession,
                              activeColor: Theme.of(context).colorScheme.primary,
                              onChanged: (bool? value) {
                                setState(() {
                                  _keepSession = value ?? true;
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                "Mantener sesión iniciada",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () async {
                              setState(() => isLoading = true);
                              
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('keep_session', _keepSession);

                              final msg = await auth.signIn(email.text, pass.text);
                              setState(() => isLoading = false);
                              _showMessage(msg);

                              if (msg.contains("exitoso")) {
                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme)),
                                  );
                                }
                              }
                            },
                            child: isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Iniciar Sesión"),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                            final msg = await auth.signUp(email.text, pass.text);
                            _showMessage(msg);
                          },
                          child: Text("¿No tienes cuenta? Regístrate", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}