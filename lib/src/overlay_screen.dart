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

  const DatamexCameraOverlayScreen({
    super.key,
    this.startsWithSelfie = false,
    this.pickFromGalleryInitially = false,
    this.useFaceDetection = false,
    this.showFaceGuides = true,
    this.config = const CameraConfig(),
  });

  @override
  ConsumerState<DatamexCameraOverlayScreen> createState() =>
      _DatamexCameraOverlayScreenState();
}

class _DatamexCameraOverlayScreenState
    extends ConsumerState<DatamexCameraOverlayScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.useFaceDetection) {
        _openFaceDetectionCamera();
      } else if (widget.pickFromGalleryInitially) {
        _openGallery();
      } else {
        _openCamera();
      }
    });
  }

  Future<void> _openFaceDetectionCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      // ✅ Leer removeBackground del provider
      final removeBackground = ref.read(datamexRemoveBackgroundProvider);
      
      final file = await Navigator.of(context).push<File?>(
        MaterialPageRoute(
          builder: (_) => FaceDetectionCameraSimple(
            // En flujo de detección facial usamos SIEMPRE la cámara frontal (selfie)
            useFrontCamera: true,
            showFaceGuides: widget.showFaceGuides,
            removeBackground: removeBackground, // ✅ Desde provider
            config: widget.config, // ✅ Propagar configuración
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
      _showPermissionDenied('cámara');
      Navigator.of(context).pop(null);
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
      _showPermissionDenied('cámara');
      Navigator.of(context).pop(null);
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
      _showPermissionDenied('galería');
      Navigator.of(context).pop(null);
    }
  }

  void _showPermissionDenied(String type) {
    // Silent: no toast per requirements
  }

  void _showError(String message) {
    // Silent: no toast per requirements
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tomar Foto')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
