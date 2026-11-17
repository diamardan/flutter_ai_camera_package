import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
/* import 'package:local_rembg/local_rembg.dart';*/
import 'package:image/image.dart' as img;
import 'edge_refinement_service.dart';
import 'matte_utils.dart';

/// Servicio centralizado para procesamiento de imágenes
/// SOLID: Única fuente de verdad para remover fondo y procesar imágenes
/// Usado por TODOS los flujos (overlay, non-overlay, galería, etc.)
class ImageProcessingService {
  /// Procesa una imagen removiendo el fondo y aplicando refinamiento de bordes
  /// 
  /// [inputFile]: Archivo de imagen de entrada
  /// [applyEdgeRefinement]: Si aplica refinamiento de bordes (opcional)
  /// [edgeBlurIntensity]: Intensidad del suavizado de bordes (0-10, default: 5.0)
  /// 
  /// Retorna:
  /// - Un objeto [ProcessedImageResult] con los archivos PNG (transparencia) y JPG (fondo blanco)
  /// - null si el procesamiento falla
  /* static Future<ProcessedImageResult?> processImageWithBackgroundRemoval({
    required File inputFile,
    bool applyEdgeRefinement = true,
    double edgeBlurIntensity = 5.0,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('[ImageProcessing] 🚀 Iniciando procesamiento con Local Rembg (preciso)');
      debugPrint('[ImageProcessing] 📂 Input: ${inputFile.path}');
      debugPrint('[ImageProcessing] 📏 Size: ${await inputFile.length()} bytes');
      debugPrint('[ImageProcessing] 🎨 Edge blur intensity: $edgeBlurIntensity');
      
      // PASO 1: Remover fondo con Local Rembg
      Uint8List? resultBytes;
      
      debugPrint('[ImageProcessing] 🎯 Usando Local Rembg...');
      
      final LocalRembgResultModel result = await LocalRembg.removeBackground(
        imagePath: inputFile.path,
        cropTheImage: true,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('[ImageProcessing] ⏱️ Local Rembg timeout');
          throw TimeoutException('Local Rembg timeout');
        },
      );
      
      resultBytes = result.imageBytes != null 
          ? Uint8List.fromList(result.imageBytes!) 
          : null;
      
      if (resultBytes == null || resultBytes.isEmpty) {
        debugPrint('[ImageProcessing] ❌ No se obtuvo resultado de remoción de fondo');
        return null;
      }
      
      stopwatch.stop();
      debugPrint('[ImageProcessing] ✅ Fondo removido en ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[ImageProcessing] 📦 Result bytes: ${resultBytes.length}');
      
      // PASO 2: Guardar PNG con transparencia
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pngPath = inputFile.path.replaceAll(
        RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false),
        '_nobg_$timestamp.png',
      );
      
      await File(pngPath).writeAsBytes(resultBytes);
      debugPrint('[ImageProcessing] 💾 PNG con transparencia guardado: $pngPath');
      
      // PASO 3: Aplicar refinamiento de bordes (opcional)
      Uint8List pngWithAlpha = resultBytes;
      
      if (applyEdgeRefinement && edgeBlurIntensity > 0) {
        try {
          stopwatch.reset();
          stopwatch.start();
          
          final refined = await EdgeRefinementService.refineEdges(
            imageBytes: pngWithAlpha,
            intensity: edgeBlurIntensity,
          );
          
          if (refined != null) {
            pngWithAlpha = refined;
            stopwatch.stop();
            debugPrint('[ImageProcessing] ✅ Edge refinement aplicado (intensity: $edgeBlurIntensity) en ${stopwatch.elapsedMilliseconds}ms');
          } else {
            debugPrint('[ImageProcessing] ⚠️ Edge refinement retornó null, usando original');
          }
        } catch (e) {
          debugPrint('[ImageProcessing] ⚠️ Edge refinement falló: $e');
          // Continuar con imagen sin refinar
        }
      } else {
        debugPrint('[ImageProcessing] ⏭️ Edge refinement deshabilitado (applyEdgeRefinement=$applyEdgeRefinement, intensity=$edgeBlurIntensity)');
      }
      
      // PASO 4: Convertir PNG → JPG con fondo blanco
      stopwatch.reset();
      stopwatch.start();
      
      debugPrint('[ImageProcessing] 🎨 Convirtiendo PNG a JPG con fondo blanco...');
      
      final Uint8List jpgBytes = MatteUtils.flattenBytesToColorJpg(
        pngWithAlpha,
        bgColor: img.ColorRgba8(255, 255, 255, 255),
        quality: 90,
      );
      
      stopwatch.stop();
      debugPrint('[ImageProcessing] ✅ JPG generado en ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[ImageProcessing] 📦 JPG bytes: ${jpgBytes.length}');
      
      // PASO 5: Guardar JPG final
      final jpgPath = inputFile.path.replaceAll(
        RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false),
        '_nobg_$timestamp.jpg',
      );
      
      final jpgFile = File(jpgPath);
      await jpgFile.writeAsBytes(jpgBytes);
      
      debugPrint('[ImageProcessing] 💾 JPG con fondo blanco guardado: $jpgPath');
      debugPrint('[ImageProcessing] 📏 JPG file size: ${await jpgFile.length()} bytes');
      
      if (!await jpgFile.exists()) {
        debugPrint('[ImageProcessing] ❌ Error: JPG no se guardó correctamente');
        return null;
      }
      
      // RETORNAR RESULTADO
      return ProcessedImageResult(
        pngFile: File(pngPath),
        jpgFile: jpgFile,
        pngBytes: pngWithAlpha,
        jpgBytes: jpgBytes,
      );
      
    } catch (e, stack) {
      debugPrint('[ImageProcessing] ❌ Error en procesamiento: $e');
      debugPrint('[ImageProcessing] Stack: $stack');
      return null;
    }
  } */
}

/// Resultado del procesamiento de imagen
class ProcessedImageResult {
  /// Archivo PNG con transparencia (canal alpha)
  final File pngFile;
  
  /// Archivo JPG con fondo blanco
  final File jpgFile;
  
  /// Bytes del PNG con transparencia
  final Uint8List pngBytes;
  
  /// Bytes del JPG con fondo blanco
  final Uint8List jpgBytes;
  
  ProcessedImageResult({
    required this.pngFile,
    required this.jpgFile,
    required this.pngBytes,
    required this.jpgBytes,
  });
}
