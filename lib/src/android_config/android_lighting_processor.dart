import 'dart:io';
import 'dart:math' show pow;
import 'package:image/image.dart' as img;
import '../models/lighting_analysis.dart';
import '../core/lighting_correction_config.dart';

/// Procesador de corrección de iluminación para Android
/// Usa algoritmos conservadores para evitar sobre-exposición
class AndroidLightingProcessor {
  /// Corrige la iluminación de una imagen de forma conservadora
  /// 
  /// Estrategia:
  /// - Para imágenes oscuras: gamma correction suave + ajuste de brillo mínimo
  /// - Para imágenes brillantes: reducción de gamma + ligera reducción de exposición
  /// - Siempre preserva detalles y evita clipping
  static Future<File> correctLighting({
    required File imageFile,
    required LightingAnalysis analysis,
  }) async {
    try {
      print('[AndroidLighting] Starting correction - brightness: ${analysis.averageBrightness.toStringAsFixed(3)}, state: ${analysis.state}');
      
      // Leer y decodificar imagen
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        print('[AndroidLighting] Failed to decode image');
        return imageFile;
      }
      
      // Determinar si es seguro aplicar corrección
      final brightness = analysis.averageBrightness;
      if (brightness < LightingCorrectionConfig.safeMinBrightness ||
          brightness > LightingCorrectionConfig.safeMaxBrightness) {
        print('[AndroidLighting] Brightness out of safe range, skipping correction');
        return imageFile;
      }
      
      img.Image corrected;
      
      if (analysis.state == LightingState.tooDark) {
        // Imagen oscura: aclarar suavemente
        corrected = _brightenImage(image, analysis);
      } else if (analysis.state == LightingState.tooBright) {
        // Imagen brillante: oscurecer suavemente
        corrected = _darkenImage(image, analysis);
      } else {
        // Óptima o fuera de rango: no corregir
        print('[AndroidLighting] State is ${analysis.state}, no correction needed');
        return imageFile;
      }
      
      // Guardar imagen corregida
      final correctedBytes = img.encodeJpg(corrected, quality: LightingCorrectionConfig.jpegQuality);
      final tempDir = imageFile.parent;
      final correctedFile = File('${tempDir.path}/corrected_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await correctedFile.writeAsBytes(correctedBytes);
      
      print('[AndroidLighting] Correction applied successfully: ${correctedFile.path}');
      return correctedFile;
      
    } catch (e, stack) {
      print('[AndroidLighting] Error during correction: $e');
      print('[AndroidLighting] Stack: $stack');
      return imageFile;
    }
  }
  
  /// Aclara una imagen oscura de forma conservadora
  static img.Image _brightenImage(img.Image image, LightingAnalysis analysis) {
    final brightness = analysis.averageBrightness;
    
    // Calcular cuánto necesitamos aclarar (target: 0.38-0.42 - MÁS CONSERVADOR)
    final targetBrightness = 0.40;
    final delta = targetBrightness - brightness;
    
    // Limitar el ajuste para evitar sobre-exposición - MUCHO MÁS CONSERVADOR
    final safeDelta = delta.clamp(0.0, 0.08); // Máximo 8% de ajuste
    
    // Convertir delta a ajuste de brillo - REDUCIDO DE 0.6 A 0.25
    final brightnessAdjust = (safeDelta * 255 * 0.25).round();
    
    // Aplicar gamma correction MUY suave - REDUCIDO DE 1.15 A 1.05
    final gamma = 1.05;
    
    print('[AndroidLighting] Brightening - delta: ${safeDelta.toStringAsFixed(3)}, adjust: $brightnessAdjust, gamma: $gamma');
    
    // Aplicar correcciones - SIN CONTRASTE para evitar saturación
    var result = img.adjustColor(
      image,
      brightness: brightnessAdjust.toDouble(),
      contrast: 1.0, // Sin cambio de contraste
    );
    
    // Aplicar gamma SIEMPRE pero muy suave
    result = _applyGammaCorrection(result, gamma);
    
    return result;
  }
  
  /// Oscurece una imagen brillante de forma conservadora
  static img.Image _darkenImage(img.Image image, LightingAnalysis analysis) {
    final brightness = analysis.averageBrightness;
    
    // Calcular cuánto necesitamos oscurecer (target: 0.55-0.60 - MÁS CONSERVADOR)
    final targetBrightness = 0.58;
    final delta = brightness - targetBrightness;
    
    // Limitar el ajuste - MUCHO MÁS CONSERVADOR
    final safeDelta = delta.clamp(0.0, 0.08); // Máximo 8% de ajuste
    
    // Convertir delta a ajuste negativo - REDUCIDO DE 0.5 A 0.20
    final brightnessAdjust = -(safeDelta * 255 * 0.20).round();
    
    // Gamma para reducir highlights - MÁS SUAVE: 0.90 → 0.95
    final gamma = 0.95;
    
    print('[AndroidLighting] Darkening - delta: ${safeDelta.toStringAsFixed(3)}, adjust: $brightnessAdjust, gamma: $gamma');
    
    // Aplicar correcciones - SIN CONTRASTE
    var result = img.adjustColor(
      image,
      brightness: brightnessAdjust.toDouble(),
      contrast: 1.0, // Sin cambio de contraste
    );
    
    // Aplicar gamma para comprimir highlights
    result = _applyGammaCorrection(result, gamma);
    
    return result;
  }
  
  /// Aplica gamma correction pixel por pixel
  static img.Image _applyGammaCorrection(img.Image image, double gamma) {
    // Pre-calcular tabla de lookup para velocidad
    final gammaTable = List<int>.generate(256, (i) {
      final normalized = i / 255.0;
      final corrected = pow(normalized, gamma);
      return (corrected * 255).round().clamp(0, 255);
    });
    
    for (final pixel in image) {
      final r = gammaTable[pixel.r.toInt()];
      final g = gammaTable[pixel.g.toInt()];
      final b = gammaTable[pixel.b.toInt()];
      
      pixel
        ..r = r
        ..g = g
        ..b = b;
    }
    
    return image;
  }
}
