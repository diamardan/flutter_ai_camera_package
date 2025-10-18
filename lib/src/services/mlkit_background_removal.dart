import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Servicio para remoción de fondo usando Google ML Kit Face Detection
/// Alternativa más rápida que local_rembg para fotos de personas
class MlKitBackgroundRemoval {
  /// Remueve el fondo dejando solo la cabeza, hombros y cabello
  /// 
  /// [imagePath] - Ruta de la imagen original
  /// [paddingFactor] - Factor de padding alrededor del rostro (1.5 = 50% más grande)
  ///   - 1.0: Solo rostro detectado (muy ajustado)
  ///   - 1.5: Incluye cabello y parte de hombros (recomendado)
  ///   - 2.0: Incluye más del torso
  /// 
  /// Retorna los bytes de la imagen procesada en PNG con fondo transparente
  static Future<Uint8List?> removeBackground({
    required String imagePath,
    double paddingFactor = 1.8,
  }) async {
    try {
      debugPrint('[MlKitBgRemoval] Iniciando procesamiento...');
      debugPrint('[MlKitBgRemoval] Imagen: $imagePath');
      debugPrint('[MlKitBgRemoval] Padding factor: $paddingFactor');
      
      final stopwatch = Stopwatch()..start();

      // 1. Cargar imagen
      final bytes = await _loadImageBytes(imagePath);
      if (bytes == null) {
        debugPrint('[MlKitBgRemoval] ❌ No se pudo cargar la imagen');
        return null;
      }

      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('[MlKitBgRemoval] ❌ No se pudo decodificar la imagen');
        return null;
      }

      debugPrint('[MlKitBgRemoval] Imagen cargada: ${image.width}x${image.height}');

      // 2. Detectar rostro con ML Kit
      final inputImage = InputImage.fromFilePath(imagePath);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: true,
          enableClassification: false,
          enableTracking: false,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      if (faces.isEmpty) {
        debugPrint('[MlKitBgRemoval] ⚠️ No se detectó rostro');
        return null;
      }

      final face = faces.first;
      final boundingBox = face.boundingBox;
      
      debugPrint('[MlKitBgRemoval] Rostro detectado en: ${boundingBox.toString()}');

      // 3. Calcular región de interés (ROI) expandida
      final roi = _calculateExpandedROI(
        boundingBox,
        image.width,
        image.height,
        paddingFactor,
      );

      debugPrint('[MlKitBgRemoval] ROI expandida: $roi');

      // 4. Crear máscara con forma elíptica/ovalada
      final mask = _createOvalMask(
        image.width,
        image.height,
        roi,
      );

      // 5. Aplicar máscara a la imagen
      final result = _applyMask(image, mask);

      // 6. Recortar al área de interés
      final cropped = _cropToROI(result, roi);

      // 7. Encodear a PNG
      final pngBytes = Uint8List.fromList(img.encodePng(cropped));

      stopwatch.stop();
      debugPrint('[MlKitBgRemoval] ✅ Completado en ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[MlKitBgRemoval] Tamaño final: ${pngBytes.length} bytes');

      return pngBytes;
    } catch (e, stackTrace) {
      debugPrint('[MlKitBgRemoval] ❌ Error: $e');
      debugPrint('[MlKitBgRemoval] Stack: $stackTrace');
      return null;
    }
  }

  /// Carga los bytes de la imagen desde la ruta
  static Future<Uint8List?> _loadImageBytes(String path) async {
    try {
      // Leer archivo directamente
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[MlKitBgRemoval] Archivo no existe: $path');
        return null;
      }
      
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[MlKitBgRemoval] Error cargando imagen: $e');
      return null;
    }
  }

  /// Calcula la región de interés expandida alrededor del rostro
  static Map<String, int> _calculateExpandedROI(
    ui.Rect boundingBox,
    int imageWidth,
    int imageHeight,
    double paddingFactor,
  ) {
    // Centro del rostro
    final centerX = boundingBox.center.dx.toInt();
    final centerY = boundingBox.center.dy.toInt();

    // Dimensiones del rostro
    final faceWidth = boundingBox.width.toInt();
    final faceHeight = boundingBox.height.toInt();

    // Expandir para incluir cabello y hombros
    // Ancho: usar el ancho del rostro * paddingFactor
    final roiWidth = (faceWidth * paddingFactor).toInt();
    
    // Alto: expandir más hacia abajo (hombros) que hacia arriba (cabello)
    // Expandir 1.5x hacia arriba (cabello) y 2x hacia abajo (hombros)
    final topExpansion = (faceHeight * 0.5 * paddingFactor).toInt();
    final bottomExpansion = (faceHeight * 1.0 * paddingFactor).toInt();
    final roiHeight = faceHeight + topExpansion + bottomExpansion;

    // Calcular coordenadas
    int left = (centerX - roiWidth ~/ 2).clamp(0, imageWidth - 1);
    int top = (centerY - faceHeight ~/ 2 - topExpansion).clamp(0, imageHeight - 1);
    int right = (left + roiWidth).clamp(0, imageWidth);
    int bottom = (top + roiHeight).clamp(0, imageHeight);

    // Ajustar si se salió de los límites
    if (right - left < roiWidth && left > 0) {
      left = (right - roiWidth).clamp(0, imageWidth - 1);
    }
    if (bottom - top < roiHeight && top > 0) {
      top = (bottom - roiHeight).clamp(0, imageHeight - 1);
    }

    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'width': right - left,
      'height': bottom - top,
      'centerX': centerX,
      'centerY': centerY,
    };
  }

  /// Crea una máscara ovalada/elíptica
  static img.Image _createOvalMask(
    int imageWidth,
    int imageHeight,
    Map<String, int> roi,
  ) {
    final mask = img.Image(width: imageWidth, height: imageHeight);

    final centerX = roi['centerX']!;
    final centerY = roi['centerY']!;
    final radiusX = (roi['width']! / 2);
    final radiusY = (roi['height']! / 2);

    // Crear máscara con forma elíptica
    for (int y = 0; y < imageHeight; y++) {
      for (int x = 0; x < imageWidth; x++) {
        // Calcular distancia normalizada al centro del óvalo
        final dx = (x - centerX) / radiusX;
        final dy = (y - centerY) / radiusY;
        final distance = dx * dx + dy * dy;

        if (distance <= 1.0) {
          // Dentro del óvalo - opaco
          // Aplicar gradiente suave en los bordes
          final alpha = distance < 0.7
              ? 255
              : ((1.0 - distance) * 255 / 0.3).clamp(0, 255).toInt();
          
          mask.setPixelRgba(x, y, 255, 255, 255, alpha);
        } else {
          // Fuera del óvalo - transparente
          mask.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    return mask;
  }

  /// Aplica la máscara a la imagen
  static img.Image _applyMask(img.Image image, img.Image mask) {
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final maskPixel = mask.getPixel(x, y);
        final alpha = maskPixel.a.toInt();

        if (alpha > 0) {
          // Mantener píxel con alpha de la máscara
          result.setPixelRgba(
            x,
            y,
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            alpha,
          );
        } else {
          // Transparente
          result.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    return result;
  }

  /// Recorta la imagen a la región de interés
  static img.Image _cropToROI(img.Image image, Map<String, int> roi) {
    return img.copyCrop(
      image,
      x: roi['left']!,
      y: roi['top']!,
      width: roi['width']!,
      height: roi['height']!,
    );
  }



  /// Método simplificado: Solo recortar sin máscara
  static Future<Uint8List?> cropToFaceRegion({
    required String imagePath,
    double paddingFactor = 1.8,
  }) async {
    try {
      debugPrint('[MlKitBgRemoval] Recortando a región del rostro...');
      
      // Cargar imagen
      final bytes = await _loadImageBytes(imagePath);
      if (bytes == null) return null;

      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Detectar rostro
      final inputImage = InputImage.fromFilePath(imagePath);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: false,
          enableContours: false,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      if (faces.isEmpty) return null;

      // Calcular ROI
      final face = faces.first;
      final roi = _calculateExpandedROI(
        face.boundingBox,
        image.width,
        image.height,
        paddingFactor,
      );

      // Solo recortar (sin remover fondo)
      final cropped = _cropToROI(image, roi);

      return Uint8List.fromList(img.encodePng(cropped));
    } catch (e) {
      debugPrint('[MlKitBgRemoval] Error en cropToFaceRegion: $e');
      return null;
    }
  }
}
