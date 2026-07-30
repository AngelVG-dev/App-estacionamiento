import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class ProgressCard extends StatelessWidget {
  final Stream<DownloadProgress> progressStream;
  final VoidCallback onCancel;

  const ProgressCard({
    required this.progressStream,
    required this.onCancel,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withOpacity(0.7) 
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.05)
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8)
              )
            ],
          ),
          child: StreamBuilder<DownloadProgress>(
            stream: progressStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text("Error al descargar mapa", style: TextStyle(color: Colors.redAccent)),
                  ],
                );
              }

              if (!snapshot.hasData) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 12),
                    Text("Iniciando descarga..."),
                  ],
                );
              }

              final progress = snapshot.data!;
              final double percentage = progress.percentageProgress / 100.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map_rounded, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 12),
                          Text(
                            "Mapa Offline",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: onCancel,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withOpacity(0.1),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 10,
                        width: (MediaQuery.of(context).size.width * 0.75) * percentage,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2)
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${progress.successfulTiles} de ${progress.maxTiles} cuadros",
                        style: TextStyle(
                          fontSize: 13, 
                          color: isDark ? Colors.white60 : Colors.black54
                        ),
                      ),
                      Text(
                        "${progress.percentageProgress.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF3B82F6)
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}