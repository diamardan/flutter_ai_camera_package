import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Cropper con detección facial: recorta basándose en rostro + hombros
class SimpleCropper {
  /// Recorta imagen a 3:4 basándose en detección facial (rostro + hombros)
  static Future<File> cropTo34(Uint8List imageBytes) async {
    print('[SimpleCropper] Starting with ${imageBytes.length} bytes');
    
    // 1. Decodificar imagen
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      print('[SimpleCropper] ERROR: Could not decode image');
      throw Exception('Could not decode image');
    }
    print('[SimpleCropper] Original: ${originalImage.width}x${originalImage.height}');
    
    // 2. Detectar rostro usando ML Kit
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_for_detection_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(imageBytes);
    
    final inputImage = InputImage.fromFile(tempFile);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableTracking: false,
        enableClassification: false,
      ),
    );
    
    final faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();
    await tempFile.delete();
    
    print('[SimpleCropper] Detected ${faces.length} faces');
    
    if (faces.isEmpty) {
      print('[SimpleCropper] No face detected, using center crop');
      return _centerCrop(originalImage);
    }
    
    // 3. Usar el primer rostro detectado
    final face = faces.first;
    final faceBounds = face.boundingBox;
    
    print('[SimpleCropper] Face bounds: ${faceBounds.left}, ${faceBounds.top}, ${faceBounds.width}, ${faceBounds.height}');
    
    final imgWidth = originalImage.width;
    final imgHeight = originalImage.height;
    
    // 4. Calcular región de crop basada en rostro + hombros
    // NUEVA ESTRATEGIA: Calcular cuánto recortar de cada lado
    
    final faceHeight = faceBounds.height;
    final faceTop = faceBounds.top;
    final faceBottom = faceBounds.top + faceHeight;
    
    // ANCHO: usar ancho completo de la imagen (no recortar horizontalmente)
    final cropWidth = imgWidth;
    final cropX = 0;
    
    // ALTO: Determinar cuánto espacio hay arriba y abajo del rostro
    final spaceAboveFace = faceTop;
    final spaceBelowFace = imgHeight - faceBottom;
    
    print('[SimpleCropper] Original image: ${imgWidth}x${imgHeight}');
    print('[SimpleCropper] Face: top=$faceTop, bottom=$faceBottom, height=$faceHeight');
    print('[SimpleCropper] Space: above=${spaceAboveFace}px, below=${spaceBelowFace}px');
    
    // Calcular cuánto recortar de cada lado
    // Queremos mantener: 35% faceHeight arriba + rostro + 0.5x faceHeight abajo
    final desiredHeadroom = (faceHeight * 0.35).round();
    final desiredShoulderSpace = (faceHeight * 0.5).round();
    
    // Recortar desde arriba: todo lo que exceda el headroom deseado
    final pixelsToCutTop = (spaceAboveFace - desiredHeadroom).clamp(0, spaceAboveFace).toInt();
    
    // Recortar desde abajo: todo lo que exceda el shoulder space deseado
    final pixelsToCutBottom = (spaceBelowFace - desiredShoulderSpace).clamp(0, spaceBelowFace).toInt();
    
    print('[SimpleCropper] Desired: headroom=${desiredHeadroom}px, shoulders=${desiredShoulderSpace}px');
    print('[SimpleCropper] Will cut: top=${pixelsToCutTop}px, bottom=${pixelsToCutBottom}px');
    
    // Aplicar el crop
    final cropY = pixelsToCutTop;
    final cropHeight = imgHeight - pixelsToCutTop - pixelsToCutBottom;
    final finalCropWidth = cropWidth;
    final finalCropHeight = cropHeight;
    
    print('[SimpleCropper] Final crop: y=$cropY, height=$cropHeight (from ${imgHeight}px)');
    print('[SimpleCropper] Result dimensions: ${finalCropWidth}x${finalCropHeight}');
    
    // 5. Hacer el crop
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: finalCropWidth,
      height: finalCropHeight,
    );
    print('[SimpleCropper] Cropped: ${croppedImage.width}x${croppedImage.height}');
    
    // 6. Redimensionar manteniendo proporciones (ancho a 900px)
    final targetWidth = 900;
    final aspectRatio = croppedImage.height / croppedImage.width;
    final targetHeight = (targetWidth * aspectRatio).round();
    
    final resized = img.copyResize(
      croppedImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
    print('[SimpleCropper] Resized: ${resized.width}x${resized.height}');
    
    // 7. Encodear a JPG con calidad alta
    print('[SimpleCropper] Encoding to JPG...');
    final jpgBytes = img.encodeJpg(resized, quality: 95);
    print('[SimpleCropper] Encoded: ${jpgBytes.length} bytes');
    
    // 8. Guardar a archivo temporal
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/cropped_$timestamp.jpg';
    final file = File(filePath);
    await file.writeAsBytes(jpgBytes, flush: true);
    print('[SimpleCropper] Saved to: $filePath');
    
    // 9. Verificar que el archivo existe y tiene contenido
    if (!file.existsSync()) {
      throw Exception('File was not created');
    }
    final fileSize = file.lengthSync();
    if (fileSize == 0) {
      throw Exception('File is empty');
    }
    print('[SimpleCropper] File verified: $fileSize bytes');
    
    return file;
  }
  
  /// Crop centrado simple si no se detecta rostro
  static Future<File> _centerCrop(img.Image originalImage) async {
    final imgWidth = originalImage.width;
    final imgHeight = originalImage.height;
    
    // Para formato portrait 3:4: usar altura completa y recortar lados
    final cropHeight = imgHeight;
    final cropWidth = (cropHeight * 3 / 4).round();
    
    // Centrar horizontalmente
    final cropX = ((imgWidth - cropWidth) / 2).round().clamp(0, imgWidth);
    final cropY = 0;
    
    final finalWidth = cropWidth > imgWidth ? imgWidth : cropWidth;
    final finalHeight = cropHeight;
    
    print('[SimpleCropper] Center crop: x=$cropX, y=$cropY, w=$finalWidth, h=$finalHeight');
    
    // Crop
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: finalWidth,
      height: finalHeight,
    );
    
    // Resize
    final resized = img.copyResize(
      croppedImage,
      width: 900,
      height: 1200,
      interpolation: img.Interpolation.linear,
    );
    
    // Encode
    final jpgBytes = img.encodeJpg(resized, quality: 95);
    
    // Save
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/cropped_$timestamp.jpg';
    final file = File(filePath);
    await file.writeAsBytes(jpgBytes, flush: true);
    
    return file;
  }
}
