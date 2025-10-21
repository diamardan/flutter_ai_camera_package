import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itc_camera_package/datamex_camera_package.dart';

/// ========================================
/// PROVIDERS DE CONFIGURACIÓN LOCAL (solo para el ejemplo)
/// ========================================

// Estos providers solo se usan en el ejemplo para probar diferentes configuraciones
final showOverlayProvider = StateProvider<bool>((ref) => false);
final useFaceDetectionProvider = StateProvider<bool>((ref) => true);
final acceptGalleryProvider = StateProvider<bool>((ref) => false);
final startsWithSelfieProvider = StateProvider<bool>((ref) => false);
final showGuidelinesWindowProvider = StateProvider<bool>((ref) => false);
final showAcceptGuidelinesCheckboxProvider = StateProvider<bool>((ref) => false);
final showFaceGuidesProvider = StateProvider<bool>((ref) => true);

/// ========================================
/// PANEL DE CONFIGURACIÓN
/// ========================================

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leer todos los estados
    final removeBackground = ref.watch(datamexRemoveBackgroundProvider);
    final showOverlay = ref.watch(showOverlayProvider);
    final useFaceDetection = ref.watch(useFaceDetectionProvider);
    final acceptGallery = ref.watch(acceptGalleryProvider);
    final startsWithSelfie = ref.watch(startsWithSelfieProvider);
    final showGuidelinesWindow = ref.watch(showGuidelinesWindowProvider);
    final showAcceptGuidelinesCheckbox = ref.watch(showAcceptGuidelinesCheckboxProvider);
    final showFaceGuides = ref.watch(showFaceGuidesProvider);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.settings, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Panel de Configuración',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Lista de switches
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Configuración de Funcionalidades',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          const Divider(height: 1),

          // 1. Remove Background (provider del paquete)
          _buildSwitchTile(
            context: context,
            value: removeBackground,
            onChanged: (value) {
              ref.read(datamexRemoveBackgroundProvider.notifier).state = value;
            },
            icon: removeBackground ? Icons.auto_fix_high : Icons.image,
            iconColor: removeBackground ? Colors.purple : Colors.grey,
            title: 'Remover fondo automáticamente',
            subtitle: removeBackground
                ? 'Procesará la imagen con IA (5-10 seg)'
                : 'Guardará la imagen original',
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 1.5. ML Kit vs Local Rembg (solo si remove background está activo)
          if (removeBackground) ...[
            _buildSwitchTile(
              context: context,
              value: ref.watch(datamexUseMlKitForBackgroundProvider),
              onChanged: (value) {
                ref.read(datamexUseMlKitForBackgroundProvider.notifier).state = value;
              },
              icon: ref.watch(datamexUseMlKitForBackgroundProvider) 
                  ? Icons.flash_on 
                  : Icons.stars,
              iconColor: ref.watch(datamexUseMlKitForBackgroundProvider) 
                  ? Colors.amber 
                  : Colors.purple,
              title: ref.watch(datamexUseMlKitForBackgroundProvider)
                  ? 'Método: ML Kit (rápido)'
                  : 'Método: Local Rembg (preciso)',
              subtitle: ref.watch(datamexUseMlKitForBackgroundProvider)
                  ? '⚡ 1-2 seg | Forma elíptica | Ideal para pruebas'
                  : '🎯 5-7 seg | Alta precisión | Recomendado para credenciales',
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],

          // 1.6. Edge Blur Intensity (solo si remove background está activo)
          if (removeBackground) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.blur_on,
                        color: Colors.purple.shade300,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Suavizado de bordes',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ref.watch(datamexEdgeBlurIntensityProvider).toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: ref.watch(datamexEdgeBlurIntensityProvider),
                    min: 0,
                    max: 10,
                    divisions: 20,
                    label: _getBlurIntensityLabel(ref.watch(datamexEdgeBlurIntensityProvider)),
                    activeColor: Colors.purple,
                    onChanged: (value) {
                      ref.read(datamexEdgeBlurIntensityProvider.notifier).state = value;
                    },
                  ),
                  Text(
                    _getBlurIntensityDescription(ref.watch(datamexEdgeBlurIntensityProvider)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],

          // 2. Show Overlay
          _buildSwitchTile(
            context: context,
            value: showOverlay,
            onChanged: (value) {
              ref.read(showOverlayProvider.notifier).state = value;
            },
            icon: showOverlay ? Icons.camera_front : Icons.camera_alt,
            iconColor: showOverlay ? Colors.blue : Colors.grey,
            title: 'Mostrar pantalla de overlay',
            subtitle: showOverlay
                ? 'Abre cámara con detección facial'
                : 'Usa selector de imagen estándar',
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 3. Use Face Detection
          _buildSwitchTile(
            context: context,
            value: useFaceDetection,
            onChanged: (value) {
              ref.read(useFaceDetectionProvider.notifier).state = value;
            },
            icon: useFaceDetection ? Icons.face : Icons.face_retouching_off,
            iconColor: useFaceDetection ? Colors.green : Colors.grey,
            title: 'Usar detección facial',
            subtitle: useFaceDetection
                ? 'Valida rostro antes de capturar'
                : 'Captura sin validación',
            enabled: showOverlay, // Solo funciona si overlay está activo
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 4. Show Face Guides
          _buildSwitchTile(
            context: context,
            value: showFaceGuides,
            onChanged: (value) {
              ref.read(showFaceGuidesProvider.notifier).state = value;
            },
            icon: showFaceGuides ? Icons.face_retouching_natural : Icons.face_retouching_off,
            iconColor: showFaceGuides ? Colors.orange : Colors.grey,
            title: 'Mostrar guías faciales',
            subtitle: showFaceGuides
                ? 'Muestra contornos y puntos del rostro'
                : 'Oculta las guías visuales',
            enabled: showOverlay && useFaceDetection,
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 5. Accept Gallery
          _buildSwitchTile(
            context: context,
            value: acceptGallery,
            onChanged: (value) {
              ref.read(acceptGalleryProvider.notifier).state = value;
            },
            icon: acceptGallery ? Icons.photo_library : Icons.photo_library_outlined,
            iconColor: acceptGallery ? Colors.teal : Colors.grey,
            title: 'Permitir selección de galería',
            subtitle: acceptGallery
                ? 'Usuario puede elegir foto existente'
                : 'Solo captura nueva',
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 6. Starts With Selfie
          _buildSwitchTile(
            context: context,
            value: startsWithSelfie,
            onChanged: (value) {
              ref.read(startsWithSelfieProvider.notifier).state = value;
            },
            icon: startsWithSelfie ? Icons.camera_front : Icons.camera_rear,
            iconColor: startsWithSelfie ? Colors.pink : Colors.grey,
            title: 'Iniciar con cámara frontal',
            subtitle: startsWithSelfie
                ? 'Abre cámara selfie (frontal)'
                : 'Abre cámara trasera',
            enabled: showOverlay,
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 7. Show Guidelines Window
          _buildSwitchTile(
            context: context,
            value: showGuidelinesWindow,
            onChanged: (value) {
              ref.read(showGuidelinesWindowProvider.notifier).state = value;
            },
            icon: showGuidelinesWindow ? Icons.list_alt : Icons.list_alt_outlined,
            iconColor: showGuidelinesWindow ? Colors.indigo : Colors.grey,
            title: 'Mostrar ventana de lineamientos',
            subtitle: showGuidelinesWindow
                ? 'Muestra pantalla con instrucciones'
                : 'Salta directamente a cámara',
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // 8. Show Accept Guidelines Checkbox
          _buildSwitchTile(
            context: context,
            value: showAcceptGuidelinesCheckbox,
            onChanged: (value) {
              ref.read(showAcceptGuidelinesCheckboxProvider.notifier).state = value;
            },
            icon: showAcceptGuidelinesCheckbox ? Icons.check_box : Icons.check_box_outline_blank,
            iconColor: showAcceptGuidelinesCheckbox ? Colors.deepOrange : Colors.grey,
            title: 'Checkbox de aceptar lineamientos',
            subtitle: showAcceptGuidelinesCheckbox
                ? 'Usuario debe aceptar para continuar'
                : 'Botón siempre habilitado',
            enabled: showGuidelinesWindow,
          ),

          const SizedBox(height: 16),

          // Botón de reset
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                // Reset a valores por defecto
                ref.read(datamexRemoveBackgroundProvider.notifier).state = true;
                ref.read(datamexEdgeBlurIntensityProvider.notifier).state = 3.0;
                ref.read(showOverlayProvider.notifier).state = false;
                ref.read(useFaceDetectionProvider.notifier).state = true;
                ref.read(acceptGalleryProvider.notifier).state = false;
                ref.read(startsWithSelfieProvider.notifier).state = false;
                ref.read(showGuidelinesWindowProvider.notifier).state = false;
                ref.read(showAcceptGuidelinesCheckboxProvider.notifier).state = false;
                ref.read(showFaceGuidesProvider.notifier).state = true;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Configuración restablecida a valores por defecto'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Restablecer valores por defecto'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SwitchListTile(
        value: enabled ? value : false,
        onChanged: enabled ? onChanged : null,
        secondary: Icon(icon, color: enabled ? iconColor : Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? Colors.black54 : Colors.grey,
          ),
        ),
        activeColor: iconColor,
      ),
    );
  }

  /// Helper: Obtener label del slider
  String _getBlurIntensityLabel(double value) {
    if (value == 0) return 'Desactivado';
    if (value <= 2) return 'Muy suave';
    if (value <= 4) return 'Suave';
    if (value <= 6) return 'Moderado';
    if (value <= 8) return 'Intenso';
    return 'Máximo';
  }

  /// Helper: Obtener descripción del slider
  String _getBlurIntensityDescription(double value) {
    if (value == 0) return '⚫ Bordes duros (sin suavizado)';
    if (value <= 2) return '🟣 Suavizado mínimo (casi imperceptible)';
    if (value <= 4) return '🟣 Suavizado suave (recomendado para fotos ID)';
    if (value <= 6) return '🟣 Suavizado moderado (bordes más suaves)';
    if (value <= 8) return '🟣 Suavizado intenso (bordes muy difuminados)';
    return '🟣 Suavizado máximo (efecto artístico)';
  }
}

/// ========================================
/// HELPER: Estado resumido
/// ========================================

class ConfigurationSummary extends ConsumerWidget {
  const ConfigurationSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = [
      if (ref.watch(datamexRemoveBackgroundProvider)) '🎨 Remove BG',
      if (ref.watch(showOverlayProvider)) '📸 Overlay',
      if (ref.watch(useFaceDetectionProvider)) '🤖 Face Detection',
      if (ref.watch(showFaceGuidesProvider)) '📐 Face Guides',
      if (ref.watch(acceptGalleryProvider)) '🖼️ Gallery',
      if (ref.watch(startsWithSelfieProvider)) '🤳 Selfie',
      if (ref.watch(showGuidelinesWindowProvider)) '📋 Guidelines',
      if (ref.watch(showAcceptGuidelinesCheckboxProvider)) '☑️ Checkbox',
    ];

    if (configs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('⚠️ Todas las funcionalidades están desactivadas'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Configuración Activa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: configs.map((config) {
                return Chip(
                  label: Text(config, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
