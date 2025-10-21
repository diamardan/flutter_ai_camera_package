import 'package:flutter/material.dart';
import 'package:itc_camera_package/datamex_camera_package.dart';

/// Ejemplo de cómo integrar el sistema de debug para depurar problemas
/// de detección facial en dispositivos específicos (ej: Samsung).
/// 
/// Este ejemplo muestra cómo:
/// 1. Inicializar el logger al inicio
/// 2. Añadir un botón flotante para acceder a los logs
/// 3. Capturar logs durante la ejecución
class DebugExampleApp extends StatelessWidget {
  const DebugExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debug Camera Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DebugExampleScreen(),
    );
  }
}

class DebugExampleScreen extends StatefulWidget {
  const DebugExampleScreen({super.key});

  @override
  State<DebugExampleScreen> createState() => _DebugExampleScreenState();
}

class _DebugExampleScreenState extends State<DebugExampleScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDebugLogger();
  }

  /// Inicializar el logger al inicio de la app
  Future<void> _initDebugLogger() async {
    try {
      await DebugLogger().init();
      await dlog('🚀 App iniciada - Debug Logger activado', tag: 'App');
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error inicializando debug logger: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Camera Example'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              'Ejemplo de depuración',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Este ejemplo muestra cómo usar el sistema de logs '
                'para depurar problemas de detección facial.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CameraWithDebugScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.camera),
              label: const Text('Abrir Cámara'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DebugLogOverlay(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('Ver Logs de Debug'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de cámara con botón flotante para acceder a logs
class CameraWithDebugScreen extends StatelessWidget {
  const CameraWithDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Widget de cámara
          FaceDetectionCameraSimple(
            useFrontCamera: true,
            requiredValidFrames: 30,
            onImageCaptured: (file) async {
              if (file != null) {
                await dlog('✅ Imagen capturada: ${file.path}', tag: 'App');
              } else {
                await dlog('⚠️ Captura cancelada o falló', tag: 'App');
              }
              
              if (!context.mounted) return;
              
              // Mostrar preview
              Navigator.of(context).pop();
              if (file != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Foto capturada: ${file.path}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            onStatusMessage: (message) async {
              await dlog('📱 Estado: $message', tag: 'Camera');
            },
          ),
          
          // Botón flotante para debug (esquina superior derecha)
          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red.withOpacity(0.8),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DebugLogOverlay(),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: const Icon(
                Icons.bug_report,
                color: Colors.white,
              ),
            ),
          ),
          
          // Botón de cerrar (esquina superior izquierda)
          Positioned(
            top: 50,
            left: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.black.withOpacity(0.5),
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ⚠️ IMPORTANTE: Inicializar el logger ANTES de runApp
  await DebugLogger().init();
  await dlog('🚀 App iniciada', tag: 'Main');
  
  runApp(const DebugExampleApp());
}
