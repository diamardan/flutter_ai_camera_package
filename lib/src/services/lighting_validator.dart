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
    
    // Calcular brillo promedio y desviación estándar
    int sum = 0;
    int count = 0;
    
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final index = y * width + x;
        if (index < yPlane.length) {
          sum += yPlane[index];
          count++;
        }
      }
    }
    
    if (count == 0) {
      return _createAnalysis(0.0, 0.0);
    }
    
    final double avgBrightness = sum / count / 255.0; // Normalizar a 0-1
    
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
    
    return _createAnalysis(avgBrightness, contrast);
  }

  /// Analiza una imagen ya capturada (bytes JPEG/PNG)
  /// Usa un muestreo simple para velocidad
  LightingAnalysis analyzeImageBytes(Uint8List imageBytes) {
    // Para velocidad, muestreamos cada N píxeles
    // Este es un análisis rápido, no preciso
    int sum = 0;
    int count = 0;
    final step = 100; // Muestrear cada 100 bytes
    
    for (int i = 0; i < imageBytes.length; i += step) {
      sum += imageBytes[i];
      count++;
    }
    
    final double avgBrightness = count > 0 ? (sum / count / 255.0) : 0.0;
    
    // Contraste aproximado
    double varianceSum = 0;
    for (int i = 0; i < imageBytes.length; i += step) {
      final brightness = imageBytes[i] / 255.0;
      final diff = brightness - avgBrightness;
      varianceSum += diff * diff;
    }
    final double contrast = count > 0 ? (varianceSum / count) : 0.0;
    
    return _createAnalysis(avgBrightness, contrast);
  }

  /// Crea el análisis basándose en los valores calculados
  LightingAnalysis _createAnalysis(double brightness, double contrast) {
    // Determinar estado
    LightingState state;
    String? message;
    bool isAcceptable;
    bool canAutoCorrect;
    
    if (brightness < thresholds.minAcceptable) {
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
      state: state,
      userMessage: message,
      isAcceptable: isAcceptable,
      canAutoCorrect: canAutoCorrect,
    );
  }
}
