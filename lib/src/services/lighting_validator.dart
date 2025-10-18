import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../models/lighting_analysis.dart';

/// Servicio para validar iluminación en tiempo real durante la captura
class LightingValidator {
  final LightingThresholds thresholds;

  const LightingValidator({
    this.thresholds = LightingThresholds.defaults,
  });

  /// Analiza un frame de la cámara (YUV420 format)
  /// 
  /// YUV420 format: Los primeros width*height bytes son el plano Y (luminancia)
  /// Solo necesitamos analizar el plano Y para determinar brillo
  LightingAnalysis analyzeYUV420Frame(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Uint8List yPlane = image.planes[0].bytes;
    
    // Tomar muestra del centro de la imagen (donde está el rostro)
    // Analizar un cuadrado del 50% del tamaño en el centro
    final sampleSize = 0.5;
    final startX = ((1 - sampleSize) / 2 * width).round();
    final endX = ((1 + sampleSize) / 2 * width).round();
    final startY = ((1 - sampleSize) / 2 * height).round();
    final endY = ((1 + sampleSize) / 2 * height).round();
    
    // Calcular brillo promedio, desviación estándar, y detectar clipping
    int sum = 0;
    int count = 0;
    int overexposedPixels = 0; // Píxeles muy brillantes (>240/255)
    int underexposedPixels = 0; // Píxeles muy oscuros (<15/255)
    
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final index = y * width + x;
        if (index < yPlane.length) {
          final value = yPlane[index];
          sum += value;
          count++;
          
          // Detectar clipping (zonas quemadas o muy oscuras)
          if (value > 240) overexposedPixels++;
          if (value < 15) underexposedPixels++;
        }
      }
    }
    
    if (count == 0) {
      return _createAnalysis(0.0, 0.0, 0.0, 0.0);
    }
    
    final double avgBrightness = sum / count / 255.0; // Normalizar a 0-1
    final double overexposedRatio = overexposedPixels / count; // % de píxeles quemados
    final double underexposedRatio = underexposedPixels / count; // % de píxeles negros
    
    // Calcular contraste (desviación estándar)
    double varianceSum = 0;
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final index = y * width + x;
        if (index < yPlane.length) {
          final brightness = yPlane[index] / 255.0;
          final diff = brightness - avgBrightness;
          varianceSum += diff * diff;
        }
      }
    }
    
    final double contrast = count > 0 ? (varianceSum / count) : 0.0;
    
    return _createAnalysis(avgBrightness, contrast, overexposedRatio, underexposedRatio);
  }

  /// Analiza una imagen ya capturada (bytes JPEG/PNG)
  /// Usa un muestreo simple para velocidad
  LightingAnalysis analyzeImageBytes(Uint8List imageBytes) {
    // Para velocidad, muestreamos cada N píxeles
    // Este es un análisis rápido, no preciso
    int sum = 0;
    int count = 0;
    int overexposedPixels = 0;
    int underexposedPixels = 0;
    final step = 100; // Muestrear cada 100 bytes
    
    for (int i = 0; i < imageBytes.length; i += step) {
      final value = imageBytes[i];
      sum += value;
      count++;
      
      if (value > 240) overexposedPixels++;
      if (value < 15) underexposedPixels++;
    }
    
    final double avgBrightness = count > 0 ? (sum / count / 255.0) : 0.0;
    final double overexposedRatio = count > 0 ? (overexposedPixels / count) : 0.0;
    final double underexposedRatio = count > 0 ? (underexposedPixels / count) : 0.0;
    
    // Contraste aproximado
    double varianceSum = 0;
    for (int i = 0; i < imageBytes.length; i += step) {
      final brightness = imageBytes[i] / 255.0;
      final diff = brightness - avgBrightness;
      varianceSum += diff * diff;
    }
    final double contrast = count > 0 ? (varianceSum / count) : 0.0;
    
    return _createAnalysis(avgBrightness, contrast, overexposedRatio, underexposedRatio);
  }

  /// Crea el análisis basándose en los valores calculados
  LightingAnalysis _createAnalysis(
    double brightness,
    double contrast,
    double overexposedRatio,
    double underexposedRatio,
  ) {
    // Determinar estado
    LightingState state;
    String? message;
    bool isAcceptable;
    bool canAutoCorrect;
    
    // Detectar zonas quemadas (clipping) - PRIORITARIO
    if (overexposedRatio > 0.15) {
      // Más del 15% de píxeles quemados
      state = LightingState.extremelyBright;
      message = 'Hay zonas muy brillantes. Aléjate de la luz directa';
      isAcceptable = false;
      canAutoCorrect = false;
    } else if (overexposedRatio > 0.08) {
      // Entre 8-15% de píxeles quemados
      state = LightingState.tooBright;
      message = 'Evita la luz directa en tu rostro';
      isAcceptable = true;
      canAutoCorrect = false; // No corregir zonas quemadas
    } else if (underexposedRatio > 0.25) {
      // Más del 25% muy oscuro
      state = LightingState.extremelyDark;
      message = 'Busca un lugar con más iluminación';
      isAcceptable = false;
      canAutoCorrect = false;
    } else if (brightness < thresholds.minAcceptable) {
      state = LightingState.extremelyDark;
      message = 'Busca un lugar con más iluminación';
      isAcceptable = false;
      canAutoCorrect = false;
    } else if (brightness < thresholds.minOptimal) {
      state = LightingState.tooDark;
      message = 'Necesitas más luz';
      isAcceptable = true;
      canAutoCorrect = true;
    } else if (brightness > thresholds.maxAcceptable) {
      state = LightingState.extremelyBright;
      message = 'Demasiada luz, busca un lugar con menos iluminación';
      isAcceptable = false;
      canAutoCorrect = false;
    } else if (brightness > thresholds.maxOptimal) {
      state = LightingState.tooBright;
      message = 'Demasiada luz';
      isAcceptable = true;
      canAutoCorrect = true;
    } else {
      state = LightingState.optimal;
      message = null;
      isAcceptable = true;
      canAutoCorrect = false;
    }
    
    // Verificar contraste bajo (imagen muy plana)
    if (contrast < thresholds.minContrast && isAcceptable) {
      message = message ?? 'Mejora la iluminación del ambiente';
      canAutoCorrect = true;
    }
    
    return LightingAnalysis(
      averageBrightness: brightness,
      contrast: contrast,
      overexposedRatio: overexposedRatio,
      underexposedRatio: underexposedRatio,
      state: state,
      userMessage: message,
      isAcceptable: isAcceptable,
      canAutoCorrect: canAutoCorrect,
    );
  }
}
