import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/lighting_analysis.dart';

/// Servicio para corregir automáticamente problemas de iluminación
class LightingCorrector {
  /// Corrige la iluminación de una imagen basándose en el análisis
  /// 
  /// Retorna un nuevo archivo con la imagen corregida, o el mismo archivo
  /// si no se necesita corrección
  static Future<File> correctLighting({
    required File imageFile,
    required LightingAnalysis analysis,
  }) async {
    print('[LightingCorrector] Starting correction');
    print('[LightingCorrector] Analysis: $analysis');
    
    // Si no necesita corrección, retornar el archivo original
    if (!analysis.canAutoCorrect) {
      print('[LightingCorrector] No correction needed');
      return imageFile;
    }
    
    // Leer y decodificar imagen
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image == null) {
      print('[LightingCorrector] ERROR: Could not decode image');
      return imageFile;
    }
    
    print('[LightingCorrector] Original: ${image.width}x${image.height}');
    print('[LightingCorrector] Brightness: ${analysis.averageBrightness.toStringAsFixed(2)}');
    
    img.Image corrected;
    
    // Aplicar corrección según el estado
    switch (analysis.state) {
      case LightingState.tooDark:
      case LightingState.slightlyDark:
        corrected = _brightenImage(image, analysis.averageBrightness);
        break;
        
      case LightingState.tooBright:
      case LightingState.slightlyBright:
        corrected = _darkenImage(image, analysis.averageBrightness);
        break;
        
      case LightingState.optimal:
        // Puede necesitar mejorar contraste
        if (analysis.contrast < 0.10) {
          corrected = _enhanceContrast(image);
        } else {
          corrected = image;
        }
        break;
        
      default:
        corrected = image;
    }
    
    // Guardar imagen corregida
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final correctedPath = '${tempDir.path}/corrected_$timestamp.jpg';
    final correctedFile = File(correctedPath);
    
    final jpgBytes = img.encodeJpg(corrected, quality: 95);
    await correctedFile.writeAsBytes(jpgBytes, flush: true);
    
    print('[LightingCorrector] Corrected image saved: $correctedPath');
    print('[LightingCorrector] Size: ${correctedFile.lengthSync()} bytes');
    
    return correctedFile;
  }

  /// Aclara una imagen oscura
  static img.Image _brightenImage(img.Image image, double currentBrightness) {
    // Calcular factor de ajuste
    // Objetivo: llevar brightness a ~0.55 (zona óptima)
    final targetBrightness = 0.55;
    final adjustment = (targetBrightness - currentBrightness) * 255;
    
    print('[LightingCorrector] Brightening by: ${adjustment.toStringAsFixed(1)}');
    
    // Aplicar ajuste de brillo
    return img.adjustColor(
      image,
      brightness: adjustment,
      // También ajustar gamma para levantar sombras
      gamma: 1.2,
    );
  }

  /// Oscurece una imagen muy brillante
  static img.Image _darkenImage(img.Image image, double currentBrightness) {
    // Calcular factor de ajuste
    // Objetivo: llevar brightness a ~0.60 (zona óptima)
    final targetBrightness = 0.60;
    final adjustment = (targetBrightness - currentBrightness) * 255;
    
    print('[LightingCorrector] Darkening by: ${adjustment.toStringAsFixed(1)}');
    
    // Aplicar ajuste de brillo
    return img.adjustColor(
      image,
      brightness: adjustment,
      // Reducir gamma para bajar highlights
      gamma: 0.85,
    );
  }

  /// Mejora el contraste de una imagen plana
  static img.Image _enhanceContrast(img.Image image) {
    print('[LightingCorrector] Enhancing contrast');
    
    return img.adjustColor(
      image,
      contrast: 1.15, // Aumentar contraste 15%
      saturation: 1.05, // Ligero aumento de saturación
    );
  }

  /// Análisis post-corrección para verificar resultados
  static Future<LightingAnalysis> analyzeImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image == null) {
      return const LightingAnalysis(
        averageBrightness: 0.0,
        contrast: 0.0,
        state: LightingState.extremelyDark,
        isAcceptable: false,
        canAutoCorrect: false,
      );
    }
    
    // Calcular brillo promedio
    int sum = 0;
    int count = 0;
    
    for (final pixel in image) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      // Luminosidad percibida
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
      sum += luminance.round();
      count++;
    }
    
    final avgBrightness = count > 0 ? (sum / count / 255.0) : 0.0;
    
    // Calcular contraste
    double varianceSum = 0;
    for (final pixel in image) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      final diff = luminance - avgBrightness;
      varianceSum += diff * diff;
    }
    final contrast = count > 0 ? (varianceSum / count) : 0.0;
    
    // Determinar estado
    LightingState state = LightingState.optimal;
    if (avgBrightness < 0.35) {
      state = LightingState.tooDark;
    } else if (avgBrightness > 0.75) {
      state = LightingState.tooBright;
    }
    
    return LightingAnalysis(
      averageBrightness: avgBrightness,
      contrast: contrast,
      state: state,
      isAcceptable: true,
      canAutoCorrect: false,
    );
  }
}
