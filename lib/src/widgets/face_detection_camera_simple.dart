import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show compute;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detection_service.dart';

/// Minimal FaceDetectionCamera implementation in a fresh file.
class FaceDetectionCameraSimple extends StatefulWidget {
  final bool useFrontCamera;
  final Function(File?) onImageCaptured;
  final int requiredValidFrames;
  final bool showFaceGuides;

  const FaceDetectionCameraSimple({
    super.key,
    this.useFrontCamera = true,
    required this.onImageCaptured,
    this.requiredValidFrames = 5,
    this.showFaceGuides = true,
  });

  @override
  State<FaceDetectionCameraSimple> createState() => _FaceDetectionCameraSimpleState();
}

class _FaceDetectionCameraSimpleState extends State<FaceDetectionCameraSimple> {
  CameraController? _controller;
  FaceDetectionService? _faceDetectionService;
  bool _initialized = false;
  bool _isCapturing = false;
  bool _isDisposed = false;
  int _validFrames = 0;
  String _statusMessage = '';
  bool _insideOval = false;
  Rect? _faceRectNorm; // rectángulo normalizado (0..1)
  List<Offset>? _normLandmarks; // puntos 0..1
  Map<String, List<Offset>>? _normContours; // contornos 0..1
  double _lightingLevel = 1.0; // 0..1
  bool _hideCameraPreview = false; // para evitar errores de textura durante transición

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { _showError('No hay cámaras disponibles'); return; }
      // Seleccionar cámara según preferencia
      final desired = widget.useFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;
      CameraDescription camera;
      try {
        camera = cameras.firstWhere((c) => c.lensDirection == desired);
      } catch (_) {
        // fallback: si no aparece marcada como front/back, intenta heurística por nombre
        if (widget.useFrontCamera) {
          final byName = cameras.firstWhere(
            (c) => c.name.toLowerCase().contains('front') || c.sensorOrientation == 270,
            orElse: () => cameras.first,
          );
          camera = byName;
        } else {
          camera = cameras.first;
        }
      }
      // Use a moderate resolution and explicit YUV format to avoid ImageReader pressure on capture
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
  // Bloquear a portrait para evitar cambios de orientación durante la captura
  try { await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp); } catch (_) {}
      _faceDetectionService = FaceDetectionService();
      if (!mounted) { try { await _controller?.dispose(); } catch (_) {} return; }
      setState(() => _initialized = true);
      await _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera init error: $e');
      _showError('Error al inicializar la cámara');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (!mounted || _isDisposed || _isCapturing) return;
    try {
      // Iluminación: promedio del plano Y (NV21)
      try {
        final bytes = image.planes.first.bytes;
        double sum = 0;
        for (int i = 0; i < bytes.length; i += 50) { // muestreo para rendimiento
          sum += bytes[i];
        }
        final avg = sum / (bytes.length / 50);
        final norm = (avg / 255.0).clamp(0.0, 1.0);
        _lightingLevel = norm;
      } catch (_) {}

      final rotation = _getRotation();
  final screen = MediaQuery.of(context).size;
      final res = await _faceDetectionService!.detectFace(image, rotation, screen);
      if (res == null) {
        // Skip update this frame to avoid resetting progress when detector is busy
        return;
      }

      Offset? normCenter = res.normalizedCenter;
      if (normCenter == null && res.normalizedFaceBounds != null) {
        final r = res.normalizedFaceBounds!;
        normCenter = Offset(r.left + r.width / 2, r.top + r.height / 2);
      }

      if (normCenter == null || !res.faceDetected) {
        // Sin rostro
        // Graceful decay instead of hard reset to avoid oscillation
        _validFrames = (_validFrames - 1).clamp(0, widget.requiredValidFrames);
        _faceRectNorm = null;
        _normLandmarks = null;
        _normContours = null;
        if (mounted && _statusMessage != '❌ No se detecta rostro') {
          setState(() {
            _insideOval = false;
            _statusMessage = '❌ No se detecta rostro';
          });
        }
        return;
      }
      // Apply mirror to center for oval detection (CameraPreview is mirrored)
      if (widget.useFrontCamera) normCenter = Offset(1.0 - normCenter.dx, normCenter.dy);

  // Ovalo más ESTRECHO manteniendo la altura original (ancho ~56%, alto ~50%).
  // Mantener sincronía con el overlay visual.
  const cx = 0.5, cy = 0.5, rx = 0.28, ry = 0.25;
      final dx = (normCenter.dx - cx) / rx;
      final dy = (normCenter.dy - cy) / ry;
      final inside = (dx * dx + dy * dy) <= 1.0;

      // Use coordinates directly without mirroring for drawing (Transform handles it)
      _faceRectNorm = res.normalizedFaceBounds;
      _normLandmarks = res.normalizedLandmarks;
      _normContours = res.normalizedContours;
      if (inside) {
        _validFrames++;
        // Mensaje tiene prioridad por iluminación si está baja
        final lowLight = _lightingLevel < 0.25;
        final nextMsg = lowLight ? '🔦 Asegúrate de estar en un lugar bien iluminado' : '✅ Mantén la posición';
        if (mounted && (!_insideOval || _statusMessage != nextMsg)) {
          setState(() {
            _insideOval = true;
            _statusMessage = nextMsg;
          });
        } else if (mounted) {
          // refresca progreso sin tocar mensaje
          setState(() {});
        }
        if (_validFrames >= widget.requiredValidFrames) await _captureImage();
      } else {
        final lowLight = _lightingLevel < 0.25;
        final nextMsg = lowLight ? '🔦 Asegúrate de estar en un lugar bien iluminado' : '🎯 Centra tu rostro';
        // Gentle decay (avoid full reset) to prevent loop
        final newValid = (_validFrames - 1).clamp(0, widget.requiredValidFrames);
        if (mounted && (_validFrames != newValid || _insideOval || _statusMessage != nextMsg)) {
          setState(() {
            _insideOval = false;
            _validFrames = newValid;
            _statusMessage = nextMsg;
          });
        } else if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Process image error: $e');
    }
  }

  InputImageRotation _getRotation() {
    if (_controller == null) return InputImageRotation.rotation0deg;
    final sensorOrientation = _controller!.description.sensorOrientation;
    return InputImageRotation.values.byName('rotation${sensorOrientation}deg');
  }

  Future<void> _captureImage() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    if (!mounted) return;
    setState(() => _isCapturing = true);
    try {
      debugPrint('[Capture] Starting capture sequence');
      // Stop stream if active to allow still capture
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
        // tiny delay to let pipeline drain
        await Future.delayed(const Duration(milliseconds: 320));
      }

      // Pause preview to reduce BufferQueue pressure on some devices
  try { await _controller!.pausePreview(); } catch (e) { debugPrint('[Capture] pausePreview error: $e'); }
  // Pequeña espera tras pausar preview para asegurar drenado
  await Future.delayed(const Duration(milliseconds: 80));
      try { await _controller!.setFlashMode(FlashMode.off); } catch (_) {}

      // Attempt capture with small retries (handles transient ImageReader issues)
      XFile pic;
      int attempts = 0;
      while (true) {
        attempts++;
        try {
          // Guard: ensure not already taking a picture
          if (_controller!.value.isTakingPicture) {
            await Future.delayed(const Duration(milliseconds: 60));
          }
          pic = await _controller!.takePicture();
          break;
        } catch (e) {
          debugPrint('[Capture] takePicture attempt $attempts failed: $e');
          if (attempts >= 3) rethrow;
          await Future.delayed(Duration(milliseconds: 150 * attempts));
        }
      }
      if (!mounted) return;
      // Espejar horizontalmente la imagen para selfies (modo espejo)
      File file = File(pic.path);
      if (widget.useFrontCamera) {
        try {
          final bytes = await file.readAsBytes(); // Uint8List
          final mirrored = await compute(_mirrorBytes, bytes);
          if (mirrored.isNotEmpty) {
            await file.writeAsBytes(mirrored, flush: true);
          }
        } catch (e) {
          debugPrint('[Capture] mirror failed, using original: $e');
        }
      }
      // Oculta la textura de la cámara durante la navegación para evitar errores de Impeller
  setState(() { _hideCameraPreview = true; });
  // Dejar que Flutter pinte el frame con la textura oculta antes de navegar
  await Future.delayed(const Duration(milliseconds: 16));
      // Navegar a pantalla de preview; si el usuario acepta, regresamos ese file; si no, reanudamos la cámara.
      bool? accepted;
      try {
        // Si se usa GoRouter, context.push devuelve el result. Ruta esperada: '/datamex-photo-preview'
        accepted = await context.push<bool>('/datamex-photo-preview', extra: file);
      } catch (_) {
        // Fallback a Navigator con inline preview
        try {
          accepted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => _InlinePreview(file: file)),
          );
        } catch (_) {
          accepted = null;
        }
      }

      if (accepted == true && mounted) {
        Navigator.of(context).pop(file);
        return;
      }

      // Usuario canceló o hubo error: reanudar preview y stream para reintentar
      if (mounted) {
        try { await _controller!.resumePreview(); } catch (_) {}
        if (!_controller!.value.isStreamingImages) {
          await _controller!.startImageStream(_processCameraImage);
        }
        setState(() {
          _isCapturing = false;
          _validFrames = 0;
          _hideCameraPreview = false;
        });
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        _showError('Error al capturar la imagen');
        setState(() => _isCapturing = false);
      }
      // Try to recover stream for user to retry
      try {
        if (mounted && _controller != null && _controller!.value.isInitialized) {
          try { await _controller!.resumePreview(); } catch (e) { debugPrint('[Capture] resumePreview error: $e'); }
          if (!_controller!.value.isStreamingImages) {
            await _controller!.startImageStream(_processCameraImage);
          }
          setState(() { _hideCameraPreview = false; });
        }
      } catch (_) {}
    }
  }

  void _showError(String msg) { /* Silent: no toast per requirements */ }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pv = _controller!.value.previewSize!;
    final pW = pv.height.toDouble(); // portrait swap
    final pH = pv.width.toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: pW,
              height: pH,
              child: Stack(children: [
        _hideCameraPreview
          ? Container(color: Colors.black)
          : CameraPreview(_controller!),
                // Mirror the overlay to match the mirrored preview
                widget.useFrontCamera
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..setEntry(0, 0, -1.0),
                        child: CustomPaint(
                          size: Size(pW, pH),
                          painter: _SimpleOverlayPainter(
                            progress: (_validFrames / widget.requiredValidFrames).clamp(0.0, 1.0),
                            faceRectNorm: _faceRectNorm,
                            landmarksNorm: widget.showFaceGuides ? _normLandmarks : null,
                            contoursNorm: widget.showFaceGuides ? _normContours : null,
                          ),
                        ),
                      )
                    : CustomPaint(
                        size: Size(pW, pH),
                        painter: _SimpleOverlayPainter(
                            progress: (_validFrames / widget.requiredValidFrames).clamp(0.0, 1.0),
                            faceRectNorm: _faceRectNorm,
                            landmarksNorm: widget.showFaceGuides ? _normLandmarks : null,
                            contoursNorm: widget.showFaceGuides ? _normContours : null,
                          ),
                      ),
              ]),
            ),
          ),
        ),
        // Mensaje guía (anclado a pantalla)
        Positioned(
          bottom: 48,
          left: 16,
          right: 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _insideOval ? Colors.green.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage.isEmpty ? 'Coloca tu rostro dentro del marco' : _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    try { _controller?.dispose(); } catch (_) {}
    _faceDetectionService?.dispose();
    super.dispose();
  }
}

class _SimpleOverlayPainter extends CustomPainter {
  final double progress;
  final Rect? faceRectNorm; // 0..1
  final List<Offset>? landmarksNorm; // 0..1
  final Map<String, List<Offset>>? contoursNorm; // 0..1
  const _SimpleOverlayPainter({
    this.progress = 0.0,
    this.faceRectNorm,
    this.landmarksNorm,
    this.contoursNorm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.65);
    final layer = Offset.zero & size;
    canvas.saveLayer(layer, Paint());
    canvas.drawRect(layer, overlay);
  final cx = size.width / 2, cy = size.height / 2;
  // Ovalo más estrecho con altura previa: ~56% ancho, ~50% alto
  final ow = size.width * 0.56, oh = size.height * 0.50;
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: ow, height: oh), clear);
    final border = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white70;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: ow, height: oh), border);
    canvas.restore();

    // Marcas de registro (esquinas) usando normalizado → pixeles
    if (faceRectNorm != null) {
      final n = faceRectNorm!;
      final r = Rect.fromLTWH(
        n.left * size.width,
        n.top * size.height,
        n.width * size.width,
        n.height * size.height,
      );
      final p = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      const len = 28.0;
      // TL
      canvas.drawLine(r.topLeft, Offset(r.left + len, r.top), p);
      canvas.drawLine(r.topLeft, Offset(r.left, r.top + len), p);
      // TR
      canvas.drawLine(r.topRight, Offset(r.right - len, r.top), p);
      canvas.drawLine(r.topRight, Offset(r.right, r.top + len), p);
      // BL
      canvas.drawLine(r.bottomLeft, Offset(r.left + len, r.bottom), p);
      canvas.drawLine(r.bottomLeft, Offset(r.left, r.bottom - len), p);
      // BR
      canvas.drawLine(r.bottomRight, Offset(r.right - len, r.bottom), p);
      canvas.drawLine(r.bottomRight, Offset(r.right, r.bottom - len), p);
    }
    // Landmark points (cyan)
    if (landmarksNorm != null) {
      final lp = Paint()..color = Colors.cyanAccent;
      for (final pt in landmarksNorm!) {
        final o = Offset(pt.dx * size.width, pt.dy * size.height);
        canvas.drawCircle(o, 2.5, lp);
      }
    }
    // Contours (yellow): draw all, but emphasize overall face contour if present
    if (contoursNorm != null && contoursNorm!.isNotEmpty) {
      final cpThin = Paint()
        ..color = Colors.yellowAccent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final cpFace = Paint()
        ..color = Colors.orangeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      contoursNorm!.forEach((name, list) {
        if (list.isEmpty) return;
        final paint = name.toLowerCase().contains('face') ? cpFace : cpThin;
        if (list.length > 1) {
          final path = Path();
          path.moveTo(list.first.dx * size.width, list.first.dy * size.height);
          for (int i = 1; i < list.length; i++) {
            path.lineTo(list[i].dx * size.width, list[i].dy * size.height);
          }
          canvas.drawPath(path, paint);
        } else {
          final o = Offset(list[0].dx * size.width, list[0].dy * size.height);
          canvas.drawCircle(o, 2.0, paint);
        }
      });
    }

    // Background ring
    final baseRing = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    // Progress ring
    final ring = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const start = -math.pi / 2;
    final rectRing = Rect.fromCenter(center: Offset(cx, cy), width: ow + 16, height: oh + 16);
    canvas.drawArc(rectRing, 0, 2 * math.pi, false, baseRing);
    final sweep = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(rectRing, start, sweep, false, ring);

    // (limpieza) variables no usadas eliminadas
  }

  @override
  bool shouldRepaint(covariant _SimpleOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.faceRectNorm != faceRectNorm ||
        oldDelegate.landmarksNorm != landmarksNorm ||
        oldDelegate.contoursNorm != contoursNorm;
  }
}

/// Inline fallback preview screen used when pushing via Navigator from the camera widget.
class _InlinePreview extends StatelessWidget {
  final File file;
  const _InlinePreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Previsualización'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              file,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Reintentar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Usar esta foto'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Top-level function for compute: flip JPG/PNG image bytes horizontally
Uint8List _mirrorBytes(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final flipped = img.flipHorizontal(decoded);
    final encoded = img.encodeJpg(flipped, quality: 95);
    return Uint8List.fromList(encoded);
  } catch (_) {
    return bytes;
  }
}
