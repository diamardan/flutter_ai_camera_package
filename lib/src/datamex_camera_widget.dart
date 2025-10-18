import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_rembg/local_rembg.dart';
import 'providers.dart';
import 'models/guideline_entry.dart';
import 'package:go_router/go_router.dart';
import 'services/edge_refinement_service.dart';
import 'services/mlkit_background_removal.dart';
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
    @Deprecated('Use datamexRemoveBackgroundProvider instead')
    this.removeBackground = true, // Deprecated: usar provider en su lugar
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
  });

  final ImageSelectedCallback onImageSelected;
  final LoadStatusCallback loadStatusCallback;
  final StatusMessageCallback changeStatusMessageCallback;
  final StateProvider<File?>? imageProvider;
  final bool showOverlay;
  final bool useFaceDetection;
  @Deprecated('Use datamexRemoveBackgroundProvider instead')
  final bool removeBackground; // Deprecated: usar provider
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
  Future<File> _processImage(File file) async {
    if (!widget.removeBackground) {
      return file; // Sin procesamiento
    }

    // Determinar qué método usar
    final useMlKit = ref.read(datamexUseMlKitForBackgroundProvider);
    final methodName = useMlKit ? 'ML Kit (rápido)' : 'Local Rembg (preciso)';
    
    widget.changeStatusMessageCallback('Eliminando fondo con $methodName...');
    widget.loadStatusCallback(true);
    
    try {
      debugPrint('[RemoveBackground] Método seleccionado: $methodName');
      final stopwatch = Stopwatch()..start();
      
      Uint8List? processedBytes;
      
      if (useMlKit) {
        // ⚡ MÉTODO RÁPIDO: ML Kit (1-2 segundos)
        debugPrint('[RemoveBackground-MLKit] Iniciando procesamiento rápido...');
        processedBytes = await MlKitBackgroundRemoval.removeBackground(
          imagePath: file.path,
          paddingFactor: 1.8, // Tamaño del óvalo (1.5 = ajustado, 2.0 = holgado)
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('ML Kit timeout');
          },
        );
      } else {
        // 🎯 MÉTODO PRECISO: Local Rembg (5-7 segundos)
        debugPrint('[RemoveBackground-LocalRembg] Iniciando procesamiento de alta calidad...');
        final LocalRembgResultModel result = await LocalRembg.removeBackground(
          imagePath: file.path,
          cropTheImage: true, // Crop automático del área segmentada
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException('Local Rembg timeout');
          },
        );
        processedBytes = result.imageBytes != null ? Uint8List.fromList(result.imageBytes!) : null;
      }
      
      stopwatch.stop();
      debugPrint('[RemoveBackground] Tiempo de procesamiento: ${stopwatch.elapsedMilliseconds}ms con $methodName');
      
      if (processedBytes != null && processedBytes.isNotEmpty) {
        // ✨ APLICAR REFINAMIENTO DE BORDES (si está habilitado)
        final edgeBlurIntensity = ref.read(datamexEdgeBlurIntensityProvider);
        var finalImageBytes = processedBytes;
        
        if (edgeBlurIntensity > 0) {
          widget.changeStatusMessageCallback('Refinando bordes...');
          debugPrint('[RemoveBackground] Aplicando refinamiento de bordes (intensidad: $edgeBlurIntensity)');
          
          final refinedBytes = await EdgeRefinementService.refineEdges(
            imageBytes: processedBytes,
            intensity: edgeBlurIntensity,
          );
          
          if (refinedBytes != null) {
            finalImageBytes = refinedBytes;
            debugPrint('[RemoveBackground] ✓ Bordes refinados exitosamente');
          } else {
            debugPrint('[RemoveBackground] ⚠ No se pudo refinar, usando imagen sin refinar');
          }
        }
        
        // Crear nombre único para evitar conflictos
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final suffix = useMlKit ? '_mlkit_nobg_$timestamp.png' : '_rembg_nobg_$timestamp.png';
        final processedPath = file.path.replaceAll(
          RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false),
          suffix,
        );
        
        final processedFile = File(processedPath);
        await processedFile.writeAsBytes(finalImageBytes);
        
        // Verificar que el archivo se guardó correctamente
        if (await processedFile.exists()) {
          widget.changeStatusMessageCallback('✓ Fondo eliminado con $methodName');
          debugPrint('[RemoveBackground] Imagen guardada: $processedPath');
          debugPrint('[RemoveBackground] Tamaño: ${finalImageBytes.length} bytes');
          widget.loadStatusCallback(false);
          return processedFile; // Retornar imagen procesada
        } else {
          throw Exception('No se pudo guardar la imagen procesada');
        }
      } else {
        throw Exception('La imagen procesada está vacía');
      }
    } on TimeoutException catch (e) {
      debugPrint('[RemoveBackground] ⚠️ Timeout: $e');
      widget.changeStatusMessageCallback('⚠ Timeout: usando imagen original');
      widget.loadStatusCallback(false);
      return file; // Retornar imagen original
    } catch (e, stackTrace) {
      debugPrint('[RemoveBackground] ❌ Error: $e');
      debugPrint('[RemoveBackground] StackTrace: $stackTrace');
      widget.changeStatusMessageCallback('⚠ Error al eliminar fondo: usando imagen original');
      widget.loadStatusCallback(false);
      return file; // Retornar imagen original
    }
  }

  Future<void> _handlePicked(XFile? image) async {
    if (image == null) {
      ref.read(_effectiveProvider.notifier).state = null;
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
      
      if (img != null) {
        // ✅ Procesar imagen ANTES de _handlePicked
        final file = File(img.path);
        final processedFile = await _processImage(file);
        ref.read(_effectiveProvider.notifier).state = processedFile;
        await _handlePicked(XFile(processedFile.path));
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
                          color: Colors.grey.shade50,
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
                          color: Colors.grey.shade50,
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
                        removeBackground: widget.removeBackground, // ✅ Pasar parámetro
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
