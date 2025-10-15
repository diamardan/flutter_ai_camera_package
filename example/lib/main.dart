import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datamex_camera_package/datamex_camera_package.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Datamex Camera Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DatamexCameraWidget(
              useFaceDetection: true,
              showGuidelinesWindow: true,
              showAcceptGuidelinesCheckbox: true,
              showFaceGuides: true,
              
              guidelinesObject: [
                GuidelineEntry('Asegúrate de tener buena iluminación.'),
                GuidelineEntry('Mantén la cámara estable.'),
                GuidelineEntry('Evita reflejos en lentes o superficies.'),
                GuidelineEntry('Coloca tu rostro en el recuadro.'),
              ],
              onImageSelected: (file) {
                if (file != null) {
                 log('Imagen seleccionada: ${file.path}');
                } else {
                  log('No se seleccionó imagen');
                }
              },
              loadStatusCallback: (loading) {
                if (loading) {
                  // opcional: mostrar indicador global
                } else {
                  // ocultar indicador
                }
              },
              changeStatusMessageCallback: (msg) {
                // opcional: mostrar mensajes de estado
              },
              imageProvider: exampleImageProvider,
              showOverlay: true, // usa overlay del paquete
              acceptChooseImageFromGallery: true,
              handleServerPhoto: false,
              placeHolderMessage: 'Presiona para tomar o elegir una foto',
            ),
            const SizedBox(height: 20),
            /* Text('Preview (provider):'),
            const SizedBox(height: 8),
            if (img != null)
              SizedBox(
                height: 120,
                child: Image.file(img),
              )
            else
              const Text('No hay imagen en el provider'), */
          ],
        ),
      ),
    );
  }
}
