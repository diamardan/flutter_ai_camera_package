import 'package:flutter/material.dart';
import 'package:itc_camera_package/datamex_camera_package.dart';

/// Pantalla de ejemplo que muestra cómo usar las animaciones Lottie
class LottieExampleScreen extends StatelessWidget {
  const LottieExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejemplos Lottie'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título
            const Text(
              '🎬 Animaciones Lottie Disponibles',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Ejemplo 1: Widget predefinido simple
            _buildExample(
              title: '1. Widget Predefinido (Simple)',
              description: 'Uso más fácil con widget específico',
              child: const ClearFaceLottieWidget(
                size: 200,
                repeat: true,
              ),
            ),
            const SizedBox(height: 32),
            
            // Ejemplo 2: Widget genérico con tamaño personalizado
            _buildExample(
              title: '2. Widget Genérico',
              description: 'Más control sobre la animación',
              child: const LottieAnimationWidget(
                animationName: LottieAnimations.clearFace,
                width: 150,
                height: 150,
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            
            // Ejemplo 3: En una tarjeta con texto
            _buildExample(
              title: '3. En Tarjeta Informativa',
              description: 'Combinado con otros widgets',
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const ClearFaceLottieWidget(size: 120),
                      const SizedBox(height: 16),
                      const Text(
                        'Coloca tu rostro dentro del óvalo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Asegúrate de estar en un lugar bien iluminado',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Ejemplo 4: Tamaños diferentes
            _buildExample(
              title: '4. Diferentes Tamaños',
              description: 'Pequeño, mediano y grande',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  ClearFaceLottieWidget(size: 80),
                  ClearFaceLottieWidget(size: 120),
                  ClearFaceLottieWidget(size: 160),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Botón para regresar
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Regresar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExample({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Center(child: child),
        ],
      ),
    );
  }
}
