import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers.dart';
import 'models/guideline_entry.dart';
import 'package:go_router/go_router.dart';
import 'services/image_processing_service.dart'; // ✅ Servicio centralizado (SOLID)
// GoRouter-only navigation is enforced; screens are resolved by routes.

typedef ImageSelectedCallback = void Function(File? image);
typedef LoadStatusCallback = void Function(bool loading);
typedef StatusMessageCallback = void Function(String msg);

/// Enhanced DatamexCameraWidget with AI face detection.
class DatamexCameraWidget extends ConsumerStatefulWidget {
  const DatamexCameraWidget({
    super.key,
    required this.onImageSelected,
    required this.loadStatusCallback,
    required this.changeStatusMessageCallback,
    this.imageProvider,
    this.showOverlay = false,
    this.useFaceDetection = true,
    this.acceptChooseImageFromGallery = false,
    this.handleServerPhoto = false,
    this.serverPhotoId = '',
    this.serverBaseUrl = '',
    this.startsWithSelfieCamera = false,
    this.placeHolderMessage = 'Presiona el botón para tomar una foto',
    this.showGuidelinesWindow = false,
    this.showAcceptGuidelinesCheckbox = false,
    this.guidelinesObject,
    this.showFaceGuides = true,
    this.showDebug = false, // ✅ Mostrar logs de debug
    this.edgeBlurIntensity = 5.0, // ✅ Nivel de suavizado de bordes (0-10)
    this.useSingleCaptureStep = false, // ✅ Usar 1 solo paso o múltiples pasos
  });

  final ImageSelectedCallback onImageSelected;
  final LoadStatusCallback loadStatusCallback;
  final StatusMessageCallback changeStatusMessageCallback;
  final StateProvider<File?>? imageProvider;
  final bool showOverlay;
  final bool useFaceDetection;
  final bool acceptChooseImageFromGallery;
  final bool handleServerPhoto;
  final String serverPhotoId;
  final String serverBaseUrl;
  final bool startsWithSelfieCamera;
  final String placeHolderMessage;
  final bool showGuidelinesWindow;
  final bool showAcceptGuidelinesCheckbox;
  /// Can be List<GuidelineEntry> or List<String>. Null allowed → screen still appears.
  final List<dynamic>? guidelinesObject;
  /// Toggle facial landmarks/contours guides in overlay.
  final bool showFaceGuides;
  /// Show debug logs and overlays
  final bool showDebug;
  /// Edge blur intensity for background removal (0-10)
  /// 0 = No blur (sharp edges), 10 = Maximum blur (soft edges)
  /// Default: 5.0
  final double edgeBlurIntensity;
  /// Use single capture step (fast mode) or multiple steps (2 ovals)
  /// false = Default mode with 2 steps (medium oval → large oval)
  /// true = Fast mode with 1 step (direct capture)
  /// Default: false
  final bool useSingleCaptureStep;

  @override
  ConsumerState<DatamexCameraWidget> createState() =>
      _DatamexCameraWidgetState();
}

class _DatamexCameraWidgetState extends ConsumerState<DatamexCameraWidget> {
  StateProvider<File?> get _effectiveProvider =>
      widget.imageProvider ?? datamexImageProvider;
  final ImagePicker _picker = ImagePicker();

  /// Procesa la imagen removiendo el fondo si está habilitado
  /// Retorna la imagen procesada o la original si falla
  /// ✅ USA SERVICIO CENTRALIZADO (SOLID)
  Future<File> _processImage(File file) async {
    // ⚠️ Si el widget está disposed, retornar imagen original sin procesamiento
    if (!mounted) {
      debugPrint('[ProcessImage] Widget disposed, skipping processing');
      return file;
    }
    
    // ✅ Leer desde provider (configurado por la app host)
    bool removeBackground;
    
    try {
      removeBackground = ref.read(datamexRemoveBackgroundProvider);
      if (!removeBackground) {
        debugPrint('[ProcessImage] Background removal DISABLED');
        return file; // Sin procesamiento
      }
    } catch (e) {
      debugPrint('[ProcessImage] Error reading providers (widget disposed?): $e');
      return file; // Retornar original si hay error
    }
    
    widget.changeStatusMessageCallback('Eliminando fondo con Local Rembg...');
    widget.loadStatusCallback(true);
    
    try {
      if (widget.showDebug) {
        debugPrint('[ProcessImage] 🚀 Using centralized ImageProcessingService (Local Rembg)');
        debugPrint('[ProcessImage] Edge blur intensity: ${widget.edgeBlurIntensity}');
      }
      
      // ✅ USAR SERVICIO CENTRALIZADO (SOLID)
      final result = await ImageProcessingService.processImageWithBackgroundRemoval(
        inputFile: file,
        applyEdgeRefinement: true,
        edgeBlurIntensity: widget.edgeBlurIntensity,
      );
      
      if (result == null) {
        throw Exception('Image processing returned null');
      }
      
      debugPrint('[ProcessImage] ✅ Processing SUCCESS - Using JPG: ${result.jpgFile.path}');
      
      // Actualizar provider si está montado
      if (mounted) {
        try {
          ref.read(_effectiveProvider.notifier).state = result.jpgFile;
        } catch (e) {
          debugPrint('[ProcessImage] Error updating provider: $e');
        }
      }
      
      return result.jpgFile;
      
    } catch (e, stack) {
      debugPrint('[ProcessImage] ❌ Error: $e');
      debugPrint('[ProcessImage] Stack: $stack');
      
      // Actualizar provider con imagen original si está montado
      if (mounted) {
        try {
          ref.read(_effectiveProvider.notifier).state = file;
        } catch (e) {
          debugPrint('[ProcessImage] Error updating provider with original: $e');
        }
      }
      
      return file;
    } finally {
      if (mounted) {
        widget.loadStatusCallback(false);
      }
    }
  }

  Future<void> _handlePicked(XFile? image) async {
    if (image == null) {
      // ⚠️ Verificar mounted antes de usar ref
      if (mounted) {
        try {
          ref.read(_effectiveProvider.notifier).state = null;
        } catch (e) {
          debugPrint('[DatamexCameraWidget] Error clearing provider (widget disposed?): $e');
        }
      }
      widget.loadStatusCallback(false);
      widget.onImageSelected.call(null);
      return;
    }
    
    // ⚠️ NO PROCESAR AQUÍ: Ya se procesó en _takePhoto() → _processImage()
    // Solo actualizar el callback final
    File file = File(image.path);
    widget.loadStatusCallback(false);
    widget.onImageSelected.call(file);
  }

  Future<void> _takePhoto(ImageSource source) async {
    debugPrint('[DatamexCameraWidget] 📸 _takePhoto() called with source: $source');
    debugPrint('[DatamexCameraWidget] 📸 This should open NATIVE camera picker (not overlay)');
    
    final permission = source == ImageSource.camera
        ? Permission.camera
        : (Platform.isAndroid ? Permission.storage : Permission.photos);
    final status = await permission.request();
    if (!status.isGranted && !status.isLimited) {
      if (!mounted) return;
      _showPermissionDialog(source == ImageSource.camera ? 'cámara' : 'galería');
      widget.loadStatusCallback(false);
      return;
    }
    widget.changeStatusMessageCallback('Abriendo ${source == ImageSource.camera ? "cámara" : "galería"}...');
    widget.loadStatusCallback(true);
    try {
      final XFile? img = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: widget.startsWithSelfieCamera ? CameraDevice.front : CameraDevice.rear,
      );
      
      // ⚠️ CRÍTICO: Verificar mounted ANTES de procesar
      if (!mounted) {
        debugPrint('[DatamexCameraWidget] Widget disposed after camera, aborting');
        return;
      }
      
      if (img != null) {
        // ✅ Mostrar diálogo de procesamiento (bloqueante) y procesar
        if (mounted) {
          try { ref.read(datamexProcessingProvider.notifier).state = true; } catch (_) {}
          widget.changeStatusMessageCallback('Procesando imagen...');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _ProcessingDialog(),
          );
        }

        File processedFile;
        try {
          final file = File(img.path);
          processedFile = await _processImage(file);
        } finally {
          if (mounted) {
            // Cerrar diálogo
            Navigator.of(context, rootNavigator: true).pop();
            try { ref.read(datamexProcessingProvider.notifier).state = false; } catch (_) {}
          }
        }

        if (!mounted) {
          debugPrint('[DatamexCameraWidget] Widget disposed after processing, aborting');
          return;
        }

        // 👉 Navegar a preview para confirmar como en overlay
        bool? accepted;
        try {
          accepted = await context.push<bool>('/datamex-photo-preview', extra: processedFile);
        } catch (_) {
          // Fallback sin GoRouter: usar el tile de vista previa directamente
          accepted = true;
        }

        if (accepted == true) {
          ref.read(_effectiveProvider.notifier).state = processedFile;
          await _handlePicked(XFile(processedFile.path));
        } else {
          // Rechazado: limpiar selección
          ref.read(_effectiveProvider.notifier).state = null;
          widget.onImageSelected.call(null);
        }
      } else {
        await _handlePicked(null);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      widget.loadStatusCallback(false);
      widget.changeStatusMessageCallback('Error al abrir ${source == ImageSource.camera ? "cámara" : "galería"}');
      // Silent: no toast per requirements
      widget.onImageSelected.call(null);
    }
  }

  void _showPermissionDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso Requerido'),
        content: Text(
          'La aplicación necesita acceso a tu $permissionType para continuar. '
          '¿Deseas ir a configuración para habilitar el permiso?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Configuración'),
          ),
        ],
      ),
    );
  }

  Widget _serverPhotoWidget(double height) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final base = widget.serverBaseUrl.replaceAll(RegExp(r'/$'), '');
    final imageUrl = '$base/media/view/${widget.serverPhotoId}?t=$timestamp';

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (c, u) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (c, u, e) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.grey),
              SizedBox(height: 8),
              Text('Error al cargar imagen'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[DatamexCameraWidget] 🏗️ Building with showOverlay=${widget.showOverlay}, useFaceDetection=${widget.useFaceDetection}');
    debugPrint('[DatamexCameraWidget] ⚡ PARAMS: showDebug=${widget.showDebug}, useSingleCaptureStep=${widget.useSingleCaptureStep}, edgeBlurIntensity=${widget.edgeBlurIntensity}');
    
    final imageFile = ref.watch(_effectiveProvider);
    final loading = ref.watch(datamexLoadingProvider);
    final showServerPhoto = widget.handleServerPhoto &&
        imageFile == null &&
        widget.serverPhotoId.isNotEmpty;
    const height = 220.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: showServerPhoto
                ? _serverPhotoWidget(height)
                : imageFile != null
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white, // Fondo blanco explícito
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10), // 10 para respetar el borde del container
                              child: Image.file(
                                imageFile,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: height,
                              ),
                            ),
                            if (widget.handleServerPhoto)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: ElevatedButton(
                                  onPressed: () {
                                    ref.read(_effectiveProvider.notifier).state = null;
                                    widget.onImageSelected.call(null);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(8),
                                    backgroundColor: Colors.red.withValues(alpha: 0.85),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white, size: 18),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white, // Fondo blanco explícito
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.placeHolderMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: loading ? null : () async {
                  // 🔍 DEBUG: Imprimir configuración actual
                  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                  debugPrint('[DatamexCameraWidget] CONFIG DEBUG:');
                  debugPrint('  showOverlay: ${widget.showOverlay}');
                  debugPrint('  useFaceDetection: ${widget.useFaceDetection}');
                  debugPrint('  showFaceGuides: ${widget.showFaceGuides}');
                  debugPrint('  showGuidelinesWindow: ${widget.showGuidelinesWindow}');
                  debugPrint('  startsWithSelfieCamera: ${widget.startsWithSelfieCamera}');
                  debugPrint('  ⚡ showDebug: ${widget.showDebug}');
                  debugPrint('  ⚡ edgeBlurIntensity: ${widget.edgeBlurIntensity}');
                  debugPrint('  ⚡ useSingleCaptureStep: ${widget.useSingleCaptureStep}');
                  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                  
                  // 1. Guidelines flow if enabled
                  if (widget.showGuidelinesWindow) {
                    final entries = _normalizeGuidelines(widget.guidelinesObject);
                    if (!context.mounted) return;
                    // GoRouter required by design (agents.md): await final result from overlay pop
                    final file = await context.push<File?>(
                      '/datamex-guidelines',
                      extra: GuidelinesConfig(
                        guidelines: entries,
                        showAcceptanceCheckbox: widget.showAcceptGuidelinesCheckbox,
                        isGuidelinesCheckboxAccepted: false,
                        useFaceDetection: widget.useFaceDetection,
                        startsWithSelfie: widget.startsWithSelfieCamera,
                        showOverlay: widget.showOverlay,
                        showFaceGuides: widget.showFaceGuides,
                        showDebug: widget.showDebug,
                        edgeBlurIntensity: widget.edgeBlurIntensity,
                        useSingleCaptureStep: widget.useSingleCaptureStep,
                        // removeBackground se lee del provider, no se pasa por extra
                      ),
                    );
                    if (!mounted) return;
                    if (file != null) {
                      // ✅ La imagen YA viene procesada (removeBackground + edge refinement)
                      // Solo actualizar estado
                      widget.loadStatusCallback(false);
                      ref.read(_effectiveProvider.notifier).state = file;
                      await _handlePicked(XFile(file.path));
                    }
                    return;
                  }

                  // 2. Direct camera overlay flow (legacy)
                  if (widget.showOverlay) {
                    final file = await context.push<File?>(
                      '/datamex-camera-overlay',
                      extra: {
                        'useFaceDetection': widget.useFaceDetection,
                        'startsWithSelfie': widget.startsWithSelfieCamera,
                        'showOverlay': widget.showOverlay,
                        'showFaceGuides': widget.showFaceGuides,
                        'showDebug': widget.showDebug,
                        'edgeBlurIntensity': widget.edgeBlurIntensity,
                        'useSingleCaptureStep': widget.useSingleCaptureStep,
                        // removeBackground se lee del provider, no se pasa por extra
                      },
                    );
                    if (!mounted) return;
                    if (file != null) {
                      // ✅ La imagen YA viene procesada (removeBackground + edge refinement)
                      // Solo actualizar estado
                      widget.loadStatusCallback(false);
                      ref.read(_effectiveProvider.notifier).state = file;
                      await _handlePicked(XFile(file.path));
                    }
                  } else {
                    await _takePhoto(ImageSource.camera);
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: Text('Tomar Foto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (widget.acceptChooseImageFromGallery)
                ElevatedButton.icon(
                  onPressed: loading ? null : () async {
                    await _takePhoto(ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'Procesando...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<GuidelineEntry> _normalizeGuidelines(List<dynamic>? input) {
    if (input == null) return const [];
    return input.map<GuidelineEntry>((e) {
      if (e is GuidelineEntry) return e;
      return GuidelineEntry(e.toString());
    }).toList(growable: false);
  }
}

/// Diálogo modal simple para indicar procesamiento en curso en el flujo nativo
class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.black.withOpacity(0.85),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
              SizedBox(height: 20),
              Text(
                'Procesando imagen...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Esto puede tardar unos segundos',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
