import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show compute;
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:local_rembg/local_rembg.dart';
import '../core/platform_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detection_service.dart';
import '../services/lighting_validator.dart';
import '../models/lighting_analysis.dart';
import '../crop/simple_cropper.dart';
import '../services/edge_refinement_service.dart';

/// 🎯 Enum para el sistema de pasos progresivos de captura
enum CaptureStep {
  step1EyesAlignment,   // Paso 1: Alinear ojos (overlay pequeño, solo ojos)
  step2FaceCentering,   // Paso 2: Centrar rostro (overlay mediano, cabeza completa)
  step3FinalCapture,    // Paso 3: Captura final (overlay completo, cabeza+hombros)
}

/// Minimal FaceDetectionCamera implementation in a fresh file.
class FaceDetectionCameraSimple extends StatefulWidget {
  final bool useFrontCamera;
  final Function(File?) onImageCaptured;
  final int requiredValidFrames;
  final bool showFaceGuides;
  final bool removeBackground; // ✅ Nuevo parámetro
  final Function(String)? onStatusMessage; // ✅ Callback para mensajes
  // Validation thresholds
  final double yawMaxDegrees;   // left/right turn tolerance
  final double pitchMaxDegrees; // up/down tilt tolerance
  final double rollMaxDegrees;  // head tilt tolerance
  final double minFaceHeight;   // min face height ratio (0..1)
  final double maxFaceHeight;   // max face height ratio (0..1)
  // Oval centering tolerance (validation ellipse is scaled by this factor; >1 means more permissive)
  final double ovalValidationScale;

  const FaceDetectionCameraSimple({
    super.key,
    this.useFrontCamera = true,
    required this.onImageCaptured,
    this.requiredValidFrames = 5,
    this.showFaceGuides = true,
    this.removeBackground = true, // ✅ Default true
    this.onStatusMessage,
    this.yawMaxDegrees = 10.0,
    this.pitchMaxDegrees = 10.0,
    this.rollMaxDegrees = 8.0,
    this.minFaceHeight = 0.34,
    this.maxFaceHeight = 0.55,
    this.ovalValidationScale = 1.12,
  });

  @override
  State<FaceDetectionCameraSimple> createState() => _FaceDetectionCameraSimpleState();
}

class _FaceDetectionCameraSimpleState extends State<FaceDetectionCameraSimple> {
  CameraController? _controller;
  FaceDetectionService? _faceDetectionService;
  LightingValidator? _lightingValidator;
  bool _initialized = false;
  bool _isCapturing = false;
  bool _isDisposed = false;
  int _validFrames = 0;
  String _statusMessage = '';
  bool _insideOval = false;
  Rect? _faceRectNorm; // rectángulo normalizado (0..1)
  List<Offset>? _normLandmarks; // puntos 0..1
  Map<String, List<Offset>>? _normContours; // contornos 0..1
  LightingAnalysis? _currentLightingAnalysis;
  bool _hideCameraPreview = false; // para evitar errores de textura durante transición
  bool _isProcessing = false; // Flag para mantener animación durante procesamiento post-captura
  
  // 🎯 SISTEMA DE PASOS PROGRESIVOS
  CaptureStep _currentStep = CaptureStep.step2FaceCentering; // ✅ Iniciar directo en paso 2
  int _stepValidFrames = 0; // Frames válidos en el paso actual
  
  // Configuración de frames requeridos por paso (REDUCIDOS)
  static const int _step1RequiredFrames = 0; // Paso 1: SALTADO
  static const int _step2RequiredFrames = 10; // Paso 2: 10 frames (~0.3s)
  static const int _step3RequiredFrames = 10; // Paso 3: 10 frames (~0.3s) antes de captura
  
  // Animación continua para evitar sensación de freeze
  double _animationProgress = 0.0;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _startAnimationTimer(); // Iniciar animación continua
  }
  
  /// 🎨 Animación continua para evitar sensación de freeze durante procesamiento
  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _animationProgress = (_animationProgress + 0.05) % 1.0;
        });
      }
    });
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
        imageFormatGroup: PlatformHandler.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
  // Bloquear a portrait para evitar cambios de orientación durante la captura
  try { await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp); } catch (_) {}
      _faceDetectionService = FaceDetectionService();
      _lightingValidator = const LightingValidator(thresholds: LightingThresholds.defaults);
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
      // Análisis de iluminación usando el validador
      LightingAnalysis? lightingAnalysis;
      try {
        lightingAnalysis = _lightingValidator?.analyzeYUV420Frame(image);
        if (lightingAnalysis != null) {
          _currentLightingAnalysis = lightingAnalysis;
        }
      } catch (e) {
        debugPrint('Lighting analysis error: $e');
        // Fallback al método anterior si falla
        final bytes = image.planes.first.bytes;
        double sum = 0;
        for (int i = 0; i < bytes.length; i += 50) { // muestreo para rendimiento
          sum += bytes[i];
        }
        final avg = sum / (bytes.length / 50);
        final norm = (avg / 255.0).clamp(0.0, 1.0);
        // Crear análisis simple de fallback
        _currentLightingAnalysis = LightingAnalysis(
          averageBrightness: norm,
          contrast: 0.0,
          state: norm < 0.35 ? LightingState.tooDark : (norm > 0.75 ? LightingState.tooBright : LightingState.optimal),
          isAcceptable: norm >= 0.20 && norm <= 0.90,
          canAutoCorrect: false,
        );
      }

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
      // Opcional: espejo de centro para chequeo; el óvalo es simétrico, así que no afecta el resultado,
      // pero mantenemos consistencia visual con la previsualización espejada.
      if (widget.useFrontCamera) {
        normCenter = Offset(1.0 - normCenter.dx, normCenter.dy);
      }

  // Parámetros del óvalo (sincronizados con el painter): ancho ≈56%, alto ≈50% del lienzo
  const cx = 0.5, cy = 0.5, rxBase = 0.28, ryBase = 0.25;
  final rx = rxBase * widget.ovalValidationScale;
  final ry = ryBase * widget.ovalValidationScale;

      // Chequeo por centro dentro del óvalo
      final dx = (normCenter.dx - cx) / rx;
      final dy = (normCenter.dy - cy) / ry;
      final centerInside = (dx * dx + dy * dy) <= 1.0;

      // Chequeos de contención:
      // 1) rectInside: TODAS las esquinas del bounding box dentro del óvalo (estricto)
      // 2) topBottomInside: los puntos medio-superior y medio-inferior del rostro dentro del óvalo (tolerante a desborde lateral)
      bool rectInside = true;
      bool topBottomInside = true;
      Rect? faceRect = res.normalizedFaceBounds;
      if (faceRect != null) {
        // Espejar rect si está en cámara frontal, para coincidir con el overlay espejado
        if (widget.useFrontCamera) {
          faceRect = Rect.fromLTWH(1.0 - (faceRect.left + faceRect.width), faceRect.top, faceRect.width, faceRect.height);
        }

        bool ptInside(Offset p) {
          final ddx = (p.dx - cx) / rx;
          final ddy = (p.dy - cy) / ry;
          return (ddx * ddx + ddy * ddy) <= 1.0;
        }

        final corners = <Offset>[
          faceRect.topLeft,
          faceRect.topRight,
          faceRect.bottomLeft,
          faceRect.bottomRight,
        ];

        // Requiere que todas las esquinas estén dentro del óvalo
  rectInside = corners.every(ptInside);

        // Puntos medio-superior e inferior sobre la vertical del centro del rostro
        final midTop = Offset(faceRect.center.dx, faceRect.top);
        final midBottom = Offset(faceRect.center.dx, faceRect.bottom);
        topBottomInside = ptInside(midTop) && ptInside(midBottom);
      }

      // Estado final (más tolerante): centro dentro y (rectángulo completamente dentro
      // o al menos top/bottom dentro para garantizar centrado vertical aceptable)
      final inside = centerInside && (rectInside || topBottomInside);

  // Use coordinates directly without mirroring for drawing (Transform handles it)
      _faceRectNorm = res.normalizedFaceBounds;
      _normLandmarks = res.normalizedLandmarks;
      _normContours = res.normalizedContours;
      // Orientation (front-facing) checks
      final yaw = (res.headEulerAngleY ?? 0).abs();   // left-right
      final pitch = (res.headEulerAngleX ?? 0).abs(); // up-down
      final roll = (res.headEulerAngleZ ?? 0).abs();  // head tilt
      final orientationOk = yaw <= widget.yawMaxDegrees &&
          pitch <= widget.pitchMaxDegrees &&
          roll <= widget.rollMaxDegrees;

      // Distance (size) checks
      final fh = (res.normalizedFaceHeight ?? 0).clamp(0.0, 1.0);
      final distanceOk = fh >= widget.minFaceHeight && fh <= widget.maxFaceHeight;

      // Lighting validation - REQUIRED for capture
      final lightingOk = _currentLightingAnalysis?.isAcceptable ?? true;
      final lightingMessage = _currentLightingAnalysis?.userMessage;

      // 🎯 SISTEMA DE PASOS PROGRESIVOS (2 PASOS)
      // Paso 1 SALTADO - Comenzamos directo en Paso 2
      
      bool stepValid = false;
      String nextMsg = '';
      int currentRequired = 0;
      double progressPercentage = 0.0;
      
      switch (_currentStep) {
        case CaptureStep.step1EyesAlignment:
          // ⏭️ PASO 1: SALTADO (no se usa)
          stepValid = false;
          nextMsg = '';
          break;

        case CaptureStep.step2FaceCentering:
          // PASO 2: Validar que toda la CABEZA esté centrada (overlay mediano, 45%)
          final faceInOval = res.faceDetected && inside && distanceOk;
          stepValid = faceInOval && orientationOk;
          currentRequired = _step2RequiredFrames;
          progressPercentage = (_stepValidFrames / currentRequired * 100).clamp(0.0, 100.0);
          
          if (!res.faceDetected) {
            nextMsg = '❌ No se detecta rostro';
          } else if (!inside) {
            nextMsg = '🎯 Coloca tu rostro en el óvalo y permanece quieto';
          } else if (!distanceOk) {
            nextMsg = fh < widget.minFaceHeight ? '📏 Acércate un poco' : '📏 Aléjate un poco';
          } else if (!orientationOk) {
            nextMsg = '👀 Mira al frente';
          } else {
            nextMsg = '✅ Preparando... ${progressPercentage.toStringAsFixed(0)}%';
          }
          break;

        case CaptureStep.step3FinalCapture:
          // PASO 3: Validación COMPLETA (overlay 100%, incluye hombros)
          final allValid = res.faceDetected && inside && orientationOk && distanceOk && lightingOk;
          stepValid = allValid;
          currentRequired = _step3RequiredFrames;
          progressPercentage = (_stepValidFrames / currentRequired * 100).clamp(0.0, 100.0);
          
          if (!res.faceDetected) {
            nextMsg = '❌ No se detecta rostro';
          } else if (!inside) {
            nextMsg = '🎯 Mantén tu rostro centrado';
          } else if (!orientationOk) {
            nextMsg = '👀 Mira al frente';
          } else if (!distanceOk) {
            nextMsg = fh < widget.minFaceHeight ? '📏 Acércate un poco' : '📏 Aléjate un poco';
          } else if (!lightingOk && lightingMessage != null) {
            nextMsg = '💡 $lightingMessage';
          } else {
            nextMsg = '📸 Capturando... ${progressPercentage.toStringAsFixed(0)}%';
          }
          break;
      }

      // Actualizar contadores y transiciones de pasos
      if (stepValid) {
        _stepValidFrames++;
        _validFrames++; // Mantener backward compatibility
        
        // Verificar si completamos el paso actual
        bool stepCompleted = false;
        switch (_currentStep) {
          case CaptureStep.step1EyesAlignment:
            stepCompleted = _stepValidFrames >= _step1RequiredFrames;
            break;
          case CaptureStep.step2FaceCentering:
            stepCompleted = _stepValidFrames >= _step2RequiredFrames;
            break;
          case CaptureStep.step3FinalCapture:
            stepCompleted = _stepValidFrames >= _step3RequiredFrames;
            break;
        }
        
        if (stepCompleted) {
          // Transición al siguiente paso
          switch (_currentStep) {
            case CaptureStep.step1EyesAlignment:
              debugPrint('[CaptureSteps] ✅ Paso 1 completado → Avanzando a Paso 2');
              if (mounted) {
                setState(() {
                  _currentStep = CaptureStep.step2FaceCentering;
                  _stepValidFrames = 0;
                  _statusMessage = '🎯 Ahora centra toda tu cabeza';
                });
              }
              break;
              
            case CaptureStep.step2FaceCentering:
              debugPrint('[CaptureSteps] ✅ Paso 2 completado → Avanzando a Paso 3 (Final)');
              if (mounted) {
                setState(() {
                  _currentStep = CaptureStep.step3FinalCapture;
                  _stepValidFrames = 0;
                  _statusMessage = '📸 Preparando captura final...';
                });
              }
              break;
              
            case CaptureStep.step3FinalCapture:
              debugPrint('[CaptureSteps] ✅ Paso 3 completado → CAPTURANDO FOTO');
              await _captureImage();
              break;
          }
        } else {
          // Actualizar UI con progreso
          if (mounted && (!_insideOval || _statusMessage != nextMsg)) {
            setState(() {
              _insideOval = true;
              _statusMessage = nextMsg;
            });
          } else if (mounted) {
            setState(() {});
          }
        }
      } else {
        // Step validation failed - decay gracefully
        final newStepValid = (_stepValidFrames - 2).clamp(0, 100); // Decay más rápido en pasos
        final newValid = (_validFrames - 1).clamp(0, widget.requiredValidFrames);
        
        if (mounted && (_stepValidFrames != newStepValid || _validFrames != newValid || _insideOval || _statusMessage != nextMsg)) {
          setState(() {
            _insideOval = false;
            _stepValidFrames = newStepValid;
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
    
    setState(() {
      _isCapturing = true;
      _isProcessing = true;
      _statusMessage = '⏳ Capturando imagen...';
    });
    
    // 🎨 Mostrar dialog de procesamiento INMEDIATAMENTE
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 20),
                    Text(
                      'Procesando imagen...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    
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
      Uint8List? mirroredBytes;
      if (widget.useFrontCamera) {
        try {
          final bytes = await file.readAsBytes();
          final mirrored = await compute(_mirrorBytes, bytes);
          if (mirrored.isNotEmpty) {
            mirroredBytes = mirrored;
          }
        } catch (e) {
          debugPrint('[Capture] mirror failed, using original: $e');
        }
      }

      // Recorte simple 3:4 - usa SimpleCropper directo con bytes
      try {
        // Si hay bytes espejados, usarlos; si no, leer del archivo original
        final bytesToCrop = mirroredBytes ?? await file.readAsBytes();
        debugPrint('[Capture] Cropping ${bytesToCrop.length} bytes');
        debugPrint('[Capture] Original file size: ${file.lengthSync()} bytes');
        
        final cropped = await SimpleCropper.cropTo34(bytesToCrop);
        file = cropped;
        
        debugPrint('[Capture] Cropped file path: ${file.path}');
        debugPrint('[Capture] Cropped file exists: ${file.existsSync()}');
        debugPrint('[Capture] Cropped file size: ${file.existsSync() ? file.lengthSync() : 0} bytes');
        
        // Verificar que la imagen no esté corrupta
        final croppedBytes = await file.readAsBytes();
        debugPrint('[Capture] Cropped bytes readable: ${croppedBytes.length} bytes');
      } catch (e, stack) {
        debugPrint('[Capture] Crop failed: $e');
        debugPrint('[Capture] Stack: $stack');
        // Si falla el crop, usar la imagen original sin recortar
      }

      // Corrección de iluminación (después del recorte, trabaja con menos píxeles)
      // TEMPORALMENTE DESHABILITADA PARA DEBUGGING
      /*
      if (_currentLightingAnalysis?.canAutoCorrect == true) {
        try {
          debugPrint('[Capture] Current lighting analysis: $_currentLightingAnalysis');
          debugPrint('[Capture] Applying lighting correction...');
          debugPrint('[Capture] File before correction: ${file.path}, size: ${file.lengthSync()} bytes');
          
          final corrected = await LightingCorrector.correctLighting(
            imageFile: file,
            analysis: _currentLightingAnalysis!,
          );
          
          debugPrint('[Capture] File after correction: ${corrected.path}, size: ${corrected.lengthSync()} bytes');
          debugPrint('[Capture] Files are same: ${file.path == corrected.path}');
          
          file = corrected;
          debugPrint('[Capture] Lighting correction completed: ${file.path}');
        } catch (e, stack) {
          debugPrint('[Capture] Lighting correction failed: $e');
          debugPrint('[Capture] Stack: $stack');
          // Continuar con la imagen sin corregir
        }
      } else {
        debugPrint('[Capture] Skipping lighting correction - canAutoCorrect: ${_currentLightingAnalysis?.canAutoCorrect}');
      }
      */
      debugPrint('[Capture] ⚠️ Lighting correction DISABLED for debugging white preview issue');

      // ✅ PROCESAR IMAGEN (removeBackground + edge refinement) ANTES DE PREVIEW
      if (widget.removeBackground) {
        debugPrint('[Capture] Starting background removal process...');
        
        try {
          // Usar Local Rembg (podría parametrizarse luego)
          final stopwatch = Stopwatch()..start();
          
          final LocalRembgResultModel result = await LocalRembg.removeBackground(
            imagePath: file.path,
            cropTheImage: true,
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw TimeoutException('Background removal timeout');
            },
          );
          
          stopwatch.stop();
          debugPrint('[Capture] Background removal completed in ${stopwatch.elapsedMilliseconds}ms');
          
          if (result.imageBytes != null && result.imageBytes!.isNotEmpty) {
            // Aplicar edge refinement si está disponible
            Uint8List finalBytes = Uint8List.fromList(result.imageBytes!);
            
            try {
              final refined = await EdgeRefinementService.refineEdges(
                imageBytes: finalBytes,
                intensity: 3, // Intensidad por defecto
              );
              if (refined != null) {
                finalBytes = refined;
                debugPrint('[Capture] Edge refinement applied');
              }
            } catch (e) {
              debugPrint('[Capture] Edge refinement failed, using unrefined: $e');
            }
            
            // Guardar imagen procesada
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final processedPath = file.path.replaceAll(
              RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false),
              '_processed_$timestamp.png',
            );
            
            final processedFile = File(processedPath);
            await processedFile.writeAsBytes(finalBytes);
            
            if (await processedFile.exists()) {
              file = processedFile; // ← Usar imagen procesada
              debugPrint('[Capture] Processed image saved: $processedPath');
            }
          }
        } on TimeoutException catch (e) {
          debugPrint('[Capture] ⚠️ Timeout: $e - using original image');
        } catch (e, stack) {
          debugPrint('[Capture] ❌ Background removal error: $e');
          debugPrint('[Capture] Stack: $stack');
          // Continuar con imagen original
        }
      }
      
      // El callback onImageCaptured recibe la imagen YA PROCESADA
      debugPrint('[Capture] Calling onImageCaptured with processed image...');
      await widget.onImageCaptured(file);
      
      // Cerrar dialog de procesamiento
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar dialog
        setState(() {
          _statusMessage = '✅ Imagen procesada';
          _isProcessing = false;
        });
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
          _stepValidFrames = 0; // Reset paso actual
          _currentStep = CaptureStep.step2FaceCentering; // Volver al paso 2 (saltamos paso 1)
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
                            currentStep: _currentStep,
                            animationProgress: _animationProgress, // 🎨 Animación continua
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
                            currentStep: _currentStep,
                            animationProgress: _animationProgress, // 🎨 Animación continua
                          ),
                      ),
              ]),
            ),
          ),
        ),
        // 📝 TEXTO DE INSTRUCCIONES (parte superior)
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Column(
              children: [
                const Text(
                  '📸 Siga las instrucciones en pantalla',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'La fotografía se tomará automáticamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 💬 MENSAJE DE ESTADO (parte superior, debajo de instrucciones)
        Positioned(
          top: 155,
          left: 16,
          right: 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _isProcessing 
                  ? Colors.blue.withValues(alpha: 0.9) // Azul durante procesamiento
                  : _insideOval 
                    ? Colors.green.withValues(alpha: 0.9) 
                    : Colors.orange.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _statusMessage.isEmpty ? '🎯 Coloca tu rostro en el óvalo' : _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
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
    _animationTimer?.cancel(); // Cancelar timer de animación
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
  final CaptureStep currentStep; // 🎯 Paso actual para cambiar tamaño de overlay
  final double animationProgress; // 🎨 Progreso de animación continua (0-1)
  
  const _SimpleOverlayPainter({
    this.progress = 0.0,
    this.faceRectNorm,
    this.landmarksNorm,
    this.contoursNorm,
    this.currentStep = CaptureStep.step2FaceCentering, // Inicio en paso 2
    this.animationProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.65);
    final layer = Offset.zero & size;
    canvas.saveLayer(layer, Paint());
    canvas.drawRect(layer, overlay);
    
    final cx = size.width / 2, cy = size.height / 2;
    
    // 🎯 TAMAÑO DE OVERLAY SEGÚN EL PASO ACTUAL
    double ovalWidthFactor;
    double ovalHeightFactor;
    Color ovalColor;
    
    switch (currentStep) {
      case CaptureStep.step1EyesAlignment:
        // Paso 1: Círculo pequeño para OJOS (25% del tamaño normal)
        ovalWidthFactor = 0.30; // 30% del ancho
        ovalHeightFactor = 0.20; // 20% del alto (circular en zona de ojos)
        ovalColor = Colors.cyan; // Color distintivo para paso 1
        break;
        
      case CaptureStep.step2FaceCentering:
        // Paso 2: Óvalo mediano para CABEZA (60% del tamaño normal)
        ovalWidthFactor = 0.45; // 45% del ancho
        ovalHeightFactor = 0.35; // 35% del alto (cabeza completa)
        ovalColor = Colors.amber; // Color distintivo para paso 2
        break;
        
      case CaptureStep.step3FinalCapture:
        // Paso 3: Óvalo completo para CABEZA + HOMBROS (tamaño original)
        ovalWidthFactor = 0.56; // 56% del ancho
        ovalHeightFactor = 0.50; // 50% del alto (incluye hombros)
        ovalColor = Colors.greenAccent; // Color distintivo para paso 3
        break;
    }
    
    final ow = size.width * ovalWidthFactor;
    final oh = size.height * ovalHeightFactor;
    
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: ow, height: oh), clear);
    
    canvas.restore();
    
    // 🎨 ANIMACIÓN ROTATIVA ALREDEDOR DEL ÓVALO (evita sensación de freeze)
    // Dibuja 3 arcos pulsantes que rotan continuamente
    final animAngle = animationProgress * 2 * math.pi;
    final arcLength = math.pi / 6; // 30 grados por arco
    
    final animatedBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = ovalColor.withOpacity(0.9);
    
    // Arco 1 (superior)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: ow + 10, height: oh + 10),
      animAngle,
      arcLength,
      false,
      animatedBorder,
    );
    
    // Arco 2 (medio, 120° desfasado)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: ow + 10, height: oh + 10),
      animAngle + (2 * math.pi / 3),
      arcLength,
      false,
      animatedBorder,
    );
    
    // Arco 3 (inferior, 240° desfasado)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: ow + 10, height: oh + 10),
      animAngle + (4 * math.pi / 3),
      arcLength,
      false,
      animatedBorder,
    );
    
    // Borde principal con color según el paso
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ovalColor.withOpacity(0.8);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: ow, height: oh), border);

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
        title: const Text(
          'Previsualización',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
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
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Texto de ayuda
                  const Text(
                    '¿La foto se ve bien?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Botones grandes y claros
                  Row(
                    children: [
                      // Botón Reintentar
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 36,
                                    semanticLabel: 'Reintentar foto',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tomar otra',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Botón Usar esta foto
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF388E3C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 36,
                                    semanticLabel: 'Aceptar foto',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Usar esta foto',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
