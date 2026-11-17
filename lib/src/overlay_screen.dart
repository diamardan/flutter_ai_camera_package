import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/face_detection_camera_simple.dart';
import 'providers.dart';
import 'dart:io';
import 'models/camera_config.dart';

class DatamexCameraOverlayScreen extends ConsumerStatefulWidget {
  final bool startsWithSelfie;
  final bool pickFromGalleryInitially;
  final bool useFaceDetection;
  final bool showFaceGuides;
  final CameraConfig config;
  final bool showDebug; // ✅ Mostrar logs de debug
  final double edgeBlurIntensity; // ✅ Nivel de suavizado de bordes (0-10)
  final bool useSingleCaptureStep; // ✅ Usar 1 solo paso o múltiples pasos
  final bool showGuidelinesDialog; // ✅ Mostrar diálogo previo a detección
  final List<String> guidelinesDialogItems; // ✅ Ítems del diálogo

  const DatamexCameraOverlayScreen({
    super.key,
    this.startsWithSelfie = false,
    this.pickFromGalleryInitially = false,
    this.useFaceDetection = false,
    this.showFaceGuides = true,
    this.config = const CameraConfig(),
    this.showDebug = false,
    this.edgeBlurIntensity = 5.0,
    this.useSingleCaptureStep = false,
    this.showGuidelinesDialog = false,
    this.guidelinesDialogItems = const [],
  });

  @override
  ConsumerState<DatamexCameraOverlayScreen> createState() =>
      _DatamexCameraOverlayScreenState();
}

class _DatamexCameraOverlayScreenState
    extends ConsumerState<DatamexCameraOverlayScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _guidelinesCountdownActive = false;
  late final List<String> _effectiveGuidelinesItems;

  @override
  void initState() {
    super.initState();
    _effectiveGuidelinesItems = widget.guidelinesDialogItems.isNotEmpty
        ? List<String>.from(widget.guidelinesDialogItems)
        : const <String>[
            'Retira gorras o sombreros.',
            'Quita lentes oscuros, audífonos u otros accesorios faciales.',
            'Asegúrate de contar con iluminación frontal uniforme.',
            'Mantén tu rostro totalmente visible y sin obstrucciones.',
          ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startInitialFlow());
    });
  }

  Future<void> _startInitialFlow() async {
    if (!mounted) return;

    if (widget.useFaceDetection && widget.showGuidelinesDialog) {
      final proceed = await _showPreCaptureGuidelinesDialog();
      if (!mounted) return;
      if (!proceed) {
        Navigator.of(context).pop(null);
        return;
      }

      setState(() => _guidelinesCountdownActive = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _guidelinesCountdownActive = false);
    }

    if (!mounted) return;
    if (widget.useFaceDetection) {
      await _openFaceDetectionCamera();
    } else if (widget.pickFromGalleryInitially) {
      await _openGallery();
    } else {
      await _openCamera();
    }
  }

  Future<bool> _showPreCaptureGuidelinesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('Antes de continuar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Retira los siguientes elementos antes de colocarte frente a la cámara:',
                ),
                const SizedBox(height: 12),
                ..._effectiveGuidelinesItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: BorderSide(
                          color: Theme.of(dialogContext).colorScheme.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Entendido',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _openFaceDetectionCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      // ✅ Leer configuración del provider
      final removeBackground = ref.read(datamexRemoveBackgroundProvider);
      
      final file = await Navigator.of(context).push<File?>(
        MaterialPageRoute(
          builder: (_) => FaceDetectionCameraSimple(
            // En flujo de detección facial usamos SIEMPRE la cámara frontal (selfie)
            useFrontCamera: true,
            showFaceGuides: widget.showFaceGuides,
            removeBackground: removeBackground, // ✅ Desde provider
            config: widget.config, // ✅ Propagar configuración
            showDebug: widget.showDebug, // ✅ Propagar showDebug
            edgeBlurIntensity: widget.edgeBlurIntensity, // ✅ Propagar intensidad
            useSingleCaptureStep: widget.useSingleCaptureStep, // ✅ Propagar modo de captura
            // Callback no-op: la imagen ya está procesada dentro de la cámara
            onImageCaptured: (_) async {
              // Ya procesada, solo esperar
            },
          ),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      // Propagar el resultado al caller - imagen YA PROCESADA
      Navigator.of(context).pop(file);
    } else {
      await _showPermissionDenied('cámara');
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  Future<void> _openCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      try {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          preferredCameraDevice: widget.startsWithSelfie
              ? CameraDevice.front
              : CameraDevice.rear,
        );
        if (!mounted) return;
        Navigator.of(context).pop(photo != null ? File(photo.path) : null);
      } catch (e) {
        debugPrint('Error opening camera: $e');
        if (mounted) {
          _showError('Error al abrir la cámara: ${e.toString()}');
          Navigator.of(context).pop(null);
        }
      }
    } else {
      await _showPermissionDenied('cámara');
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  Future<void> _openGallery() async {
    final status = Platform.isAndroid
        ? await Permission.storage.request()
        : await Permission.photos.request();

    if (!mounted) return;

    if (status.isGranted || status.isLimited) {
      try {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (!mounted) return;
        Navigator.of(context).pop(photo != null ? File(photo.path) : null);
      } catch (e) {
        debugPrint('Error opening gallery: $e');
        if (mounted) {
          _showError('Error al abrir la galería: ${e.toString()}');
          Navigator.of(context).pop(null);
        }
      }
    } else {
      await _showPermissionDenied('galería');
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  /// Muestra diálogo cuando el permiso es denegado.
  Future<void> _showPermissionDenied(String type) async {
    final primary = Theme.of(context).colorScheme.primary;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          type == 'cámara'
              ? Icons.camera_alt_outlined
              : Icons.photo_library_outlined,
          color: primary,
          size: 48,
        ),
        title: Text(
          'Permiso de ${type.toUpperCase()} Requerido',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Necesitas habilitar el acceso a la $type para continuar. '
          'Ve a Configuración > Permisos y activa el permiso de $type '
          'para esta aplicación.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                    openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text(
                      'Configuración',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    // Silent: no toast per requirements
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tomar Foto')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _guidelinesCountdownActive
                  ? 'Preparando cámara...'
                  : 'Inicializando cámara...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
