import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class ModernDialogs {

  static Future<bool?> showSelectSourceDialog({
    required BuildContext context,
    required String title,
    required String content,
    IconData icon = Icons.storage_rounded,
    Color color = const Color(0xFF3B82F6),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext context) {
        return FadeIn(
          duration: const Duration(milliseconds: 300),
          child: Stack(
            children: [
              // Fondo desenfocado
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),
              // El Diálogo
              AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.95),
                elevation: 15,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                title: Row(
                  children: [
                    Icon(icon, color: color, size: 30),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Text(title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
                      ),
                    ),
                  ],
                ),
                content: Text(content, style: const TextStyle(fontSize: 16)),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  // Boton de cancelar (izquierda)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text("Cancelar", 
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black45)
                    ),
                  ),
                  
                  // Grupo de acciones
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Boton para solo local
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text("Solo Local", 
                          style: TextStyle(color: color, fontWeight: FontWeight.w600)
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Boton para la nube
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("En la Nube"),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmText,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FadeIn(
          duration: const Duration(milliseconds: 300),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
              AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                content: Text(content, style: const TextStyle(fontSize: 16)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text("No", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}