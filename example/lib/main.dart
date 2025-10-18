import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datamex_camera_package/datamex_camera_package.dart';
import 'package:go_router/go_router.dart';
import 'settings_panel.dart'; // Importar el panel de configuración

// Proveedor local para manejar la imagen desde el host (opcional)
final exampleImageProvider = StateProvider<File?>((ref) => null);

void main() {
  runApp(const ProviderScope(child: ExampleApp()));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GoRouter host with Home route + package routes
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        datamexGuidelinesRoute(path: '/datamex-guidelines', name: 'datamexGuidelines'),
        datamexOverlayRoute(path: '/datamex-camera-overlay', name: 'datamexCameraOverlay'),
        datamexPreviewRoute(path: '/datamex-photo-preview', name: 'datamexPhotoPreview'),
      ],
    );

    return MaterialApp.router(
      title: 'Datamex Camera Package Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: router,
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leer configuraciones desde los providers
    final showOverlay = ref.watch(showOverlayProvider);
    final useFaceDetection = ref.watch(useFaceDetectionProvider);
    final acceptGallery = ref.watch(acceptGalleryProvider);
    final startsWithSelfie = ref.watch(startsWithSelfieProvider);
    final showGuidelinesWindow = ref.watch(showGuidelinesWindowProvider);
    final showAcceptGuidelinesCheckbox = ref.watch(showAcceptGuidelinesCheckboxProvider);
    final showFaceGuides = ref.watch(showFaceGuidesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datamex Camera Example'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título y descripción
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.camera_alt, size: 32, color: Colors.blue),
                          SizedBox(width: 12),
                          Text(
                            'Demo Interactiva',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Configura los parámetros del widget y prueba diferentes combinaciones.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Panel de configuración
              const SettingsPanel(),
              
              const SizedBox(height: 16),
              
              // Resumen de configuración activa
              const ConfigurationSummary(),
              
              const SizedBox(height: 24),
              
              // Widget de cámara
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.widgets, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Widget de Cámara',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DatamexCameraWidget(
                        // Usar las configuraciones de los providers
                        // removeBackground se configura vía provider (datamexRemoveBackgroundProvider)
                        showOverlay: showOverlay,
                        useFaceDetection: useFaceDetection,
                        acceptChooseImageFromGallery: acceptGallery,
                        startsWithSelfieCamera: startsWithSelfie,
                        showGuidelinesWindow: showGuidelinesWindow,
                        showAcceptGuidelinesCheckbox: showAcceptGuidelinesCheckbox,
                        showFaceGuides: showFaceGuides,
                        
                        guidelinesObject: [
                          GuidelineEntry('Asegúrate de tener buena iluminación.'),
                          GuidelineEntry('Mantén la cámara estable.'),
                          GuidelineEntry('Evita reflejos en lentes o superficies.'),
                          GuidelineEntry('Coloca tu rostro en el recuadro.'),
                        ],
                        
                        onImageSelected: (file) {
                          if (file != null) {
                            log('✅ Imagen seleccionada: ${file.path}');
                            log('📊 Tamaño archivo: ${file.lengthSync()} bytes');
                            
                            // Verificar si tiene fondo removido
                            if (file.path.contains('_nobg_')) {
                              log('🎨 ¡FONDO REMOVIDO EXITOSAMENTE!');
                            }
                          } else {
                            log('❌ No se seleccionó imagen');
                          }
                        },
                        
                        loadStatusCallback: (loading) {
                          log('⏳ Loading: $loading');
                        },
                        
                        changeStatusMessageCallback: (msg) {
                          log('💬 Status: $msg');
                        },
                        
                        imageProvider: exampleImageProvider,
                        handleServerPhoto: false,
                        placeHolderMessage: 'Presiona para tomar o elegir una foto',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
