import 'dart:io';
import 'dart:async';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers.dart';
import 'models/guideline_entry.dart';
import 'package:go_router/go_router.dart';
// import 'services/image_processing_service.dart'; // ⚠️ DESHABILITADO: local_rembg causa problema de 16KB page size
// GoRouter-only navigation is enforced; screens are resolved by routes.

typedef ImageSelectedCallback = void Function(File? image);
typedef LoadStatusCallback = void Function(bool loading);
typedef StatusMessageCallback = void Function(String msg);

const List<String> _defaultCaptureGuidelineItems = <String>[
  'Retira gorras o sombreros.',
  'Quita lentes oscuros, audífonos u otros accesorios faciales.',
  'Asegúrate de contar con iluminación frontal uniforme.',
  'Mantén tu rostro totalmente visible y sin obstrucciones.',
];

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
    this.showGuidelinesDialog = false,
    this.captureGuidelinesItems = _defaultCaptureGuidelineItems,
    this.showFaceGuides = true,
    this.showDebug = false, // ✅ Mostrar logs de debug
    this.edgeBlurIntensity = 5.0, // ✅ Nivel de suavizado de bordes (0-10)
    this.useSingleCaptureStep = false, // ✅ Usar 1 solo paso o múltiples pasos
    this.showRetakeButton = false,
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
  final bool showGuidelinesDialog;
  final List<String> captureGuidelinesItems;

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

  /// Show "Tomar otra foto" button when displaying a server photo.
  /// Default: false
  final bool showRetakeButton;

  @override
  ConsumerState<DatamexCameraWidget> createState() =>
      _DatamexCameraWidgetState();
}

class _DatamexCameraWidgetState extends ConsumerState<DatamexCameraWidget> {
  StateProvider<File?> get _effectiveProvider =>
      widget.imageProvider ?? datamexImageProvider;
  final ImagePicker _picker = ImagePicker();
  bool _captureButtonLocked = false;

  /// Procesa la imagen removiendo el fondo si está habilitado
  /// Retorna la imagen procesada o la original si falla
  /// ⚠️ DESHABILITADO: local_rembg causa problema de 16KB page size en la tienda
  Future<File> _processImage(File file) async {
    // ⚠️ MÉTODO COMENTADO: local_rembg removido para evitar problema de 16KB page size
    // Ahora simplemente retorna la imagen original sin procesamiento
    debugPrint(
        '[ProcessImage] ⏭️ Background removal DISABLED - local_rembg removed (16KB page size issue)');

    // Actualizar provider si está montado
    if (mounted) {
      try {
        ref.read(_effectiveProvider.notifier).state = file;
      } catch (e) {
        debugPrint('[ProcessImage] Error updating provider: $e');
      }
    }

    return file;

    /* ORIGINAL CODE COMMENTED OUT:
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
    */
  }

  Future<void> _handlePicked(XFile? image) async {
    if (image == null) {
      // ⚠️ Verificar mounted antes de usar ref
      if (mounted) {
        try {
          ref.read(_effectiveProvider.notifier).state = null;
        } catch (e) {
          debugPrint(
              '[DatamexCameraWidget] Error clearing provider (widget disposed?): $e');
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
    debugPrint(
        '[DatamexCameraWidget] 📸 _takePhoto() called with source: $source');
    debugPrint(
        '[DatamexCameraWidget] 📸 This should open NATIVE camera picker (not overlay)');

    final permission = source == ImageSource.camera
        ? Permission.camera
        : (Platform.isAndroid ? Permission.storage : Permission.photos);
    final status = await permission.request();
    if (!status.isGranted && !status.isLimited) {
      if (!mounted) return;
      _showPermissionDialog(
          source == ImageSource.camera ? 'cámara' : 'galería');
      widget.loadStatusCallback(false);
      return;
    }
    widget.changeStatusMessageCallback(
        'Abriendo ${source == ImageSource.camera ? "cámara" : "galería"}...');
    widget.loadStatusCallback(true);
    try {
      final XFile? img = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: widget.startsWithSelfieCamera
            ? CameraDevice.front
            : CameraDevice.rear,
      );

      // ⚠️ CRÍTICO: Verificar mounted ANTES de procesar
      if (!mounted) {
        debugPrint(
            '[DatamexCameraWidget] Widget disposed after camera, aborting');
        return;
      }

      if (img != null) {
        // ✅ Mostrar diálogo de procesamiento (bloqueante) y procesar
        if (mounted) {
          try {
            ref.read(datamexProcessingProvider.notifier).state = true;
          } catch (_) {}
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
            try {
              ref.read(datamexProcessingProvider.notifier).state = false;
            } catch (_) {}
          }
        }

        if (!mounted) {
          debugPrint(
              '[DatamexCameraWidget] Widget disposed after processing, aborting');
          return;
        }

        // 👉 Navegar a preview para confirmar como en overlay
        bool? accepted;
        try {
          accepted = await context.push<bool>('/datamex-photo-preview',
              extra: processedFile);
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
      widget.changeStatusMessageCallback(
          'Error al abrir ${source == ImageSource.camera ? "cámara" : "galería"}');
      // Silent: no toast per requirements
      widget.onImageSelected.call(null);
    }
  }

  Future<void> _handleCaptureButton() async {
    if (mounted) {
      setState(() => _captureButtonLocked = true);
    }
    try {
      if (widget.showGuidelinesWindow) {
        final entries = _normalizeGuidelines(widget.guidelinesObject);
        if (!context.mounted) return;
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
            showGuidelinesDialog: widget.showGuidelinesDialog,
            guidelinesDialogItems: widget.captureGuidelinesItems,
          ),
        );
        if (!mounted) return;
        if (file != null) {
          widget.loadStatusCallback(false);
          ref.read(_effectiveProvider.notifier).state = file;
          await _handlePicked(XFile(file.path));
        }
        return;
      }
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
            'showGuidelinesDialog': widget.showGuidelinesDialog,
            'guidelinesDialogItems': widget.captureGuidelinesItems,
          },
        );
        if (!mounted) return;
        if (file != null) {
          widget.loadStatusCallback(false);
          ref.read(_effectiveProvider.notifier).state = file;
          await _handlePicked(XFile(file.path));
        }
      } else {
        await _takePhoto(ImageSource.camera);
      }
    } finally {
      if (mounted) {
        setState(() => _captureButtonLocked = false);
      }
    }
  }

  void _showPermissionDialog(String permissionType) {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          permissionType == 'cámara'
              ? Icons.camera_alt_outlined
              : Icons.photo_library_outlined,
          color: primary,
          size: 48,
        ),
        title: Text(
          'Permiso de ${permissionType.toUpperCase()} Requerido',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Necesitas habilitar el acceso a la $permissionType para continuar. '
          'Ve a Configuración > Permisos y activa el permiso de $permissionType '
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
                  onPressed: () => Navigator.pop(dialogContext),
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
                    Navigator.pop(dialogContext);
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

  Widget _serverPhotoWidget(double height) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final base = widget.serverBaseUrl.replaceAll(RegExp(r'/$'), '');
    final imageUrl =
        '$base/media/view-img/${widget.serverPhotoId}?t=$timestamp';

    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(12),
        dashPattern: const [8, 4],
        color: Colors.grey.shade400,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (c, u) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (c, u, e) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(height: 12),
                Text(
                  'La fotografía no se encontró en el servidor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comuníquese con soporte de la aplicación para resolver el problema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '[DatamexCameraWidget] 🏗️ Building with showOverlay=${widget.showOverlay}, useFaceDetection=${widget.useFaceDetection}');
    debugPrint(
        '[DatamexCameraWidget] ⚡ PARAMS: showDebug=${widget.showDebug}, useSingleCaptureStep=${widget.useSingleCaptureStep}, edgeBlurIntensity=${widget.edgeBlurIntensity}');

    final imageFile = ref.watch(_effectiveProvider);
    final loading = ref.watch(datamexLoadingProvider);
    final showServerPhoto = widget.handleServerPhoto &&
        imageFile == null &&
        widget.serverPhotoId.isNotEmpty;
    final showPlaceholder = !showServerPhoto && imageFile == null;
    const height = 220.0;

    final placeholderWidget = DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(12),
        dashPattern: const [8, 4],
        color: Colors.grey.shade400,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 260),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.placeHolderMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (!widget.acceptChooseImageFromGallery)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: (loading || _captureButtonLocked)
                        ? null
                        : _handleCaptureButton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Tomar Foto',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          if (showServerPhoto)
            Column(
              children: [
                SizedBox(
                  height: height,
                  width: double.infinity,
                  child: _serverPhotoWidget(height),
                ),
                if (widget.showRetakeButton) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: (loading || _captureButtonLocked)
                          ? null
                          : () {
                              ref.read(_effectiveProvider.notifier).state = null;
                              widget.onImageSelected.call(null);
                              _handleCaptureButton();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'Tomar otra foto',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else if (imageFile != null)
            DottedBorder(
              options: RoundedRectDottedBorderOptions(
                radius: const Radius.circular(12),
                dashPattern: const [8, 4],
                color: Colors.grey.shade400,
                strokeWidth: 1.5,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              imageFile!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 180,
                            ),
                          ),
                          if (widget.handleServerPhoto)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () {
                                  ref
                                      .read(_effectiveProvider.notifier)
                                      .state = null;
                                  widget.onImageSelected.call(null);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(_effectiveProvider.notifier)
                              .state = null;
                          widget.onImageSelected.call(null);
                          _handleCaptureButton();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        label: const Text(
                          'Tomar otra foto',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            placeholderWidget,
          if (showPlaceholder && widget.acceptChooseImageFromGallery)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (loading || _captureButtonLocked)
                          ? null
                          : _handleCaptureButton,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Tomar Foto'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading
                          ? null
                          : () async {
                              await _takePhoto(ImageSource.gallery);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Galería'),
                    ),
                  ),
                ],
              ),
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
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
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
