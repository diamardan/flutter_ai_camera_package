import 'dart:io';
import '../models/lighting_analysis.dart';
import '../core/platform_handler.dart';
import '../ios_config/ios_lighting_processor.dart';
import '../android_config/android_lighting_processor.dart';

/// Servicio para corregir automáticamente problemas de iluminación
/// Delega a procesadores específicos por plataforma para mejores resultados
class LightingCorrector {
  /// Corrige la iluminación usando el procesador apropiado para la plataforma
  /// 
  /// - iOS: usa IOSLightingProcessor
  /// - Android: usa AndroidLightingProcessor
  /// - Otras plataformas: retorna imagen sin cambios
  /// 
  /// Estrategia conservadora:
  /// - Solo corrige si brightness está en rango seguro (0.25-0.75)
  /// - Ajustes limitados a ±15% para evitar sobre-exposición
  /// - Usa gamma correction para preservar detalles
  static Future<File> correctLighting({
    required File imageFile,
    required LightingAnalysis analysis,
  }) async {
    try {
      // Solo corregir si el análisis indica que es posible
      if (!analysis.canAutoCorrect) {
        print('[LightingCorrector] Analysis indicates correction not recommended');
        return imageFile;
      }
      
      // Delegar a procesador específico de plataforma
      if (PlatformHandler.isIOS) {
        return await IOSLightingProcessor.correctLighting(
          imageFile: imageFile,
          analysis: analysis,
        );
      } else if (PlatformHandler.isAndroid) {
        return await AndroidLightingProcessor.correctLighting(
          imageFile: imageFile,
          analysis: analysis,
        );
      } else {
        print('[LightingCorrector] Unsupported platform, returning original');
        return imageFile;
      }
    } catch (e, stack) {
      print('[LightingCorrector] Error: $e');
      print('[LightingCorrector] Stack: $stack');
      return imageFile;
    }
  }
}

