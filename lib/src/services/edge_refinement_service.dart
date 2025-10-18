import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

/// Servicio para refinar los bordes de imágenes con fondo removido
class EdgeRefinementService {
  /// Suaviza los bordes de una imagen PNG con transparencia
  /// 
  /// [imageBytes] - Bytes de la imagen PNG con canal alpha
  /// [intensity] - Intensidad del difuminado (0-10)
  ///   - 0: Sin difuminado (bordes duros)
  ///   - 3: Difuminado suave (recomendado)
  ///   - 5: Difuminado moderado
  ///   - 10: Difuminado intenso
  /// 
  /// Retorna los bytes de la imagen procesada
  static Future<Uint8List?> refineEdges({
    required Uint8List imageBytes,
    required double intensity,
  }) async {
    if (intensity <= 0) {
      return imageBytes; // Sin procesamiento
    }

    try {
      debugPrint('[EdgeRefinement] Iniciando refinamiento (intensidad: $intensity)...');
      final stopwatch = Stopwatch()..start();

      // Decodificar imagen
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('[EdgeRefinement] ❌ No se pudo decodificar la imagen');
        return null;
      }

      // Aplicar refinamiento según la intensidad
      final processedImage = await _applyEdgeRefinement(image, intensity);

      // Encodear de vuelta a PNG
      final processedBytes = Uint8List.fromList(img.encodePng(processedImage));

      stopwatch.stop();
      debugPrint('[EdgeRefinement] ✅ Completado en ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[EdgeRefinement] Tamaño original: ${imageBytes.length} bytes');
      debugPrint('[EdgeRefinement] Tamaño procesado: ${processedBytes.length} bytes');

      return processedBytes;
    } catch (e, stackTrace) {
      debugPrint('[EdgeRefinement] ❌ Error: $e');
      debugPrint('[EdgeRefinement] Stack: $stackTrace');
      return null;
    }
  }

  /// Aplica el refinamiento de bordes
  static Future<img.Image> _applyEdgeRefinement(
    img.Image image,
    double intensity,
  ) async {
    // Convertir intensidad a radio de blur (0-10 → 0-5 pixels)
    final blurRadius = (intensity / 2).round().clamp(0, 5);
    
    if (blurRadius == 0) {
      return image;
    }

    debugPrint('[EdgeRefinement] Aplicando blur con radio: $blurRadius px');

    // Crear máscara del canal alpha
    final alphaMask = _extractAlphaMask(image);

    // Aplicar gaussian blur a la máscara
    final blurredMask = img.gaussianBlur(alphaMask, radius: blurRadius);

    // Aplicar la máscara suavizada de vuelta a la imagen
    final result = _applyBlurredMask(image, blurredMask);

    return result;
  }

  /// Extrae el canal alpha como imagen en escala de grises
  static img.Image _extractAlphaMask(img.Image source) {
    final mask = img.Image(width: source.width, height: source.height);

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a.toInt();
        
        // Crear píxel en escala de grises con el valor del alpha
        mask.setPixelRgba(x, y, alpha, alpha, alpha, 255);
      }
    }

    return mask;
  }

  /// Aplica la máscara difuminada al canal alpha de la imagen original
  static img.Image _applyBlurredMask(img.Image source, img.Image blurredMask) {
    final result = img.Image(width: source.width, height: source.height);

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final sourcePixel = source.getPixel(x, y);
        final maskPixel = blurredMask.getPixel(x, y);
        
        // Usar el valor R de la máscara como nuevo alpha
        final newAlpha = maskPixel.r.toInt();
        
        // Mantener RGB original, solo cambiar alpha
        result.setPixelRgba(
          x,
          y,
          sourcePixel.r.toInt(),
          sourcePixel.g.toInt(),
          sourcePixel.b.toInt(),
          newAlpha,
        );
      }
    }

    return result;
  }

  /// Método alternativo: Feathering (desvanecimiento gradual en los bordes)
  /// Este método es más suave y natural que el blur
  static Future<Uint8List?> applyFeathering({
    required Uint8List imageBytes,
    required double intensity,
  }) async {
    if (intensity <= 0) {
      return imageBytes;
    }

    try {
      debugPrint('[EdgeRefinement] Aplicando feathering (intensidad: $intensity)...');
      final stopwatch = Stopwatch()..start();

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Feathering radius (0-10 → 2-20 pixels)
      final featherRadius = (intensity * 2).round().clamp(2, 20);
      
      final processed = _applyFeatheringEffect(image, featherRadius);
      final processedBytes = Uint8List.fromList(img.encodePng(processed));

      stopwatch.stop();
      debugPrint('[EdgeRefinement] ✅ Feathering completado en ${stopwatch.elapsedMilliseconds}ms');

      return processedBytes;
    } catch (e) {
      debugPrint('[EdgeRefinement] ❌ Error en feathering: $e');
      return null;
    }
  }

  /// Aplica efecto de feathering (desvanecimiento gradual)
  static img.Image _applyFeatheringEffect(img.Image source, int radius) {
    final result = img.Image(width: source.width, height: source.height);

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a.toInt();

        if (alpha == 0) {
          // Píxel completamente transparente
          result.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }

        if (alpha == 255) {
          // Píxel completamente opaco
          // Verificar si está cerca del borde
          final distanceToEdge = _getDistanceToTransparentEdge(source, x, y, radius);
          
          if (distanceToEdge < radius) {
            // Aplicar gradiente de transparencia
            final factor = distanceToEdge / radius;
            final newAlpha = (alpha * factor).round().clamp(0, 255);
            
            result.setPixelRgba(
              x,
              y,
              pixel.r.toInt(),
              pixel.g.toInt(),
              pixel.b.toInt(),
              newAlpha,
            );
          } else {
            // Mantener opaco
            result.setPixelRgba(
              x,
              y,
              pixel.r.toInt(),
              pixel.g.toInt(),
              pixel.b.toInt(),
              alpha,
            );
          }
        } else {
          // Píxel semi-transparente, mantener
          result.setPixelRgba(
            x,
            y,
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            alpha,
          );
        }
      }
    }

    return result;
  }

  /// Calcula la distancia al borde transparente más cercano
  static double _getDistanceToTransparentEdge(
    img.Image image,
    int x,
    int y,
    int maxRadius,
  ) {
    for (var radius = 1; radius <= maxRadius; radius++) {
      // Verificar en círculo alrededor del píxel
      for (var angle = 0; angle < 360; angle += 45) {
        final radians = angle * 3.14159 / 180;
        final checkX = (x + radius * cos(radians)).round();
        final checkY = (y + radius * sin(radians)).round();

        // Verificar límites
        if (checkX < 0 || checkX >= image.width || 
            checkY < 0 || checkY >= image.height) {
          return radius.toDouble();
        }

        // Verificar si es transparente
        final pixel = image.getPixel(checkX, checkY);
        if (pixel.a < 128) {
          // Encontrado borde transparente
          return radius.toDouble();
        }
      }
    }

    return maxRadius.toDouble();
  }

  /// Método simple: Anti-aliasing en los bordes
  static Future<Uint8List?> applyAntiAliasing({
    required Uint8List imageBytes,
  }) async {
    try {
      debugPrint('[EdgeRefinement] Aplicando anti-aliasing...');
      
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Aplicar un ligero blur solo en píxeles semi-transparentes
      final processed = _smoothSemiTransparentPixels(image);
      
      return Uint8List.fromList(img.encodePng(processed));
    } catch (e) {
      debugPrint('[EdgeRefinement] ❌ Error en anti-aliasing: $e');
      return null;
    }
  }

  /// Suaviza solo los píxeles semi-transparentes (bordes)
  static img.Image _smoothSemiTransparentPixels(img.Image source) {
    final result = img.Image(width: source.width, height: source.height);

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a.toInt();

        // Solo procesar píxeles semi-transparentes (bordes)
        if (alpha > 0 && alpha < 255) {
          // Promediar con vecinos
          final smoothed = _averageWithNeighbors(source, x, y);
          result.setPixelRgba(
            x,
            y,
            smoothed[0],
            smoothed[1],
            smoothed[2],
            smoothed[3],
          );
        } else {
          // Mantener píxeles opacos o transparentes
          result.setPixelRgba(
            x,
            y,
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            alpha,
          );
        }
      }
    }

    return result;
  }

  /// Promedia un píxel con sus vecinos
  static List<int> _averageWithNeighbors(img.Image image, int x, int y) {
    int sumR = 0, sumG = 0, sumB = 0, sumA = 0;
    int count = 0;

    // 3x3 kernel
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        final ny = y + dy;

        if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
          final pixel = image.getPixel(nx, ny);
          sumR += pixel.r.toInt();
          sumG += pixel.g.toInt();
          sumB += pixel.b.toInt();
          sumA += pixel.a.toInt();
          count++;
        }
      }
    }

    return [
      (sumR / count).round(),
      (sumG / count).round(),
      (sumB / count).round(),
      (sumA / count).round(),
    ];
  }

  /// Función auxiliar para coseno
  static double cos(double radians) {
    return (radians * 180 / 3.14159).toInt().toDouble();
  }

  /// Función auxiliar para seno
  static double sin(double radians) {
    return (radians * 180 / 3.14159).toInt().toDouble();
  }
}
