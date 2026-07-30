import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  // Verificacion si ya hay una sesión activa al abrir la app
  bool isUserLoggedIn() {
    return supabase.auth.currentUser != null;
  }

  Future<String> signUp(String email, String password) async {
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user != null) return "Registro exitoso ✅. Ya puedes iniciar sesión.";
      return "No se pudo completar el registro.";
    } on AuthException catch (e) {
      return _translateError(e.message);
    } catch (e) {
      return "Error de conexión. Verifica tu internet.";
    }
  }

  // Login Seguro
  Future<String> signIn(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return "Login exitoso ✅";
    } on AuthException catch (e) {
      return _translateError(e.message);
    } catch (e) {
      return "Error de conexión. Verifica tu internet.";
    }
  }

  // Cerrar Sesión
  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  String _translateError(String message) {
    if (message.toLowerCase().contains("invalid login credentials")) return "Correo o contraseña incorrectos ❌";
    if (message.toLowerCase().contains("user already registered")) return "Este correo ya está registrado en el sistema.";
    if (message.toLowerCase().contains("password should be at least")) return "La contraseña es muy débil (Mínimo 6 caracteres).";
    if (message.toLowerCase().contains("invalid email")) return "El formato del correo no es válido.";
    return "Ocurrió un error de autenticación."; 
  }
}