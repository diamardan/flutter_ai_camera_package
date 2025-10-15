import 'dart:io';
import '../models/lighting_analysis.dart';

/// Servicio para corregir automáticamente problemas de iluminación
/// NOTA: Corrección automática DESACTIVADA por degradación de calidad
class LightingCorrector {
  /// Retorna siempre la imagen original sin modificar
  /// La corrección automática causaba sobresaturación
  static Future<File> correctLighting({
    required File imageFile,
    required LightingAnalysis analysis,
  }) async {
    print('[LightingCorrector] Auto-correction DISABLED - returning original image');
    print('[LightingCorrector] Analysis: $analysis');
    return imageFile;
  }
}
