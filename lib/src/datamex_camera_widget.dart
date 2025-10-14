import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers.dart';
import 'models/guideline_entry.dart';
import 'package:go_router/go_router.dart';
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
    this.removeBackground = false,
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
  final bool removeBackground;
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

  Future<void> _handlePicked(XFile? image) async {
    if (image == null) {
      ref.read(_effectiveProvider.notifier).state = null;
      widget.loadStatusCallback(false);
      widget.onImageSelected.call(null);
      return;
    }
    widget.changeStatusMessageCallback('Procesando imagen...');
    await Future.delayed(const Duration(milliseconds: 100));
    final file = File(image.path);
    ref.read(_effectiveProvider.notifier).state = file;
    if (widget.removeBackground) {
      widget.changeStatusMessageCallback('Eliminando fondo...');
      await Future.delayed(const Duration(milliseconds: 200));
    }
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
      await _handlePicked(img);
    } catch (e) {
      debugPrint('Error picking image: $e');
      widget.loadStatusCallback(false);
      widget.changeStatusMessageCallback('Error al abrir ${source == ImageSource.camera ? "cámara" : "galería"}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
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
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              imageFile,
                              fit: BoxFit.cover,
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
                      ),
                    );
                    if (!mounted) return;
                    if (file != null) {
                      widget.loadStatusCallback(true);
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
                    widget.loadStatusCallback(true);
                    await _handlePicked(file == null ? null : XFile(file.path));
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
