import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Servicio para agregar fondos personalizados a imágenes sin fondo (PNG transparente)
class CustomBackgroundService {
  /// Agrega un fondo de color sólido a una imagen PNG con transparencia
  /// 
  /// [imageBytes]: Bytes de la imagen PNG con canal alpha (fondo transparente)
  /// [backgroundColor]: Color del fondo a aplicar
  /// 
  /// Returns: Bytes de la imagen PNG con el nuevo fondo
  static Future<Uint8List?> addSolidBackground({
    required Uint8List imageBytes,
    required Color backgroundColor,
  }) async {
    try {
      // Decodificar imagen
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        debugPrint('[CustomBackground] Error: No se pudo decodificar la imagen');
        return null;
      }

      // Crear imagen de fondo con el color especificado
      final img.Image background = img.Image(
        width: originalImage.width,
        height: originalImage.height,
      );

      // Rellenar con el color de fondo
      final bgColor = img.ColorRgba8(
        backgroundColor.red,
        backgroundColor.green,
        backgroundColor.blue,
        255, // Opaco
      );
      
      img.fill(background, color: bgColor);

      // Componer: fondo + imagen con transparencia
      img.compositeImage(background, originalImage);

      // Codificar a PNG
      final Uint8List result = Uint8List.fromList(img.encodePng(background));
      
      debugPrint('[CustomBackground] ✓ Fondo sólido aplicado (${backgroundColor.toString()})');
      return result;
    } catch (e) {
      debugPrint('[CustomBackground] ❌ Error al agregar fondo: $e');
      return null;
    }
  }

  /// Agrega un fondo con gradiente a una imagen PNG con transparencia
  /// 
  /// [imageBytes]: Bytes de la imagen PNG con canal alpha
  /// [gradientColors]: Lista de colores para el gradiente (mínimo 2)
  /// [gradientBegin]: Punto inicial del gradiente (default: topCenter)
  /// [gradientEnd]: Punto final del gradiente (default: bottomCenter)
  /// 
  /// Returns: Bytes de la imagen PNG con gradiente de fondo
  static Future<Uint8List?> addGradientBackground({
    required Uint8List imageBytes,
    required List<Color> gradientColors,
    Alignment gradientBegin = Alignment.topCenter,
    Alignment gradientEnd = Alignment.bottomCenter,
  }) async {
    try {
      if (gradientColors.length < 2) {
        debugPrint('[CustomBackground] Error: Se requieren al menos 2 colores para gradiente');
        return null;
      }

      // Decodificar imagen original
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        debugPrint('[CustomBackground] Error: No se pudo decodificar la imagen');
        return null;
      }

      final width = originalImage.width;
      final height = originalImage.height;

      // Crear imagen de fondo con gradiente
      final img.Image background = img.Image(width: width, height: height);

      // Calcular posiciones del gradiente
      final startX = ((gradientBegin.x + 1) / 2 * width).toInt();
      final startY = ((gradientBegin.y + 1) / 2 * height).toInt();
      final endX = ((gradientEnd.x + 1) / 2 * width).toInt();
      final endY = ((gradientEnd.y + 1) / 2 * height).toInt();

      // Aplicar gradiente píxel por píxel
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          // Calcular distancia relativa en la dirección del gradiente
          final dx = x - startX;
          final dy = y - startY;
          final totalDx = endX - startX;
          final totalDy = endY - startY;
          
          double t = 0.0;
          if (totalDx != 0 || totalDy != 0) {
            t = ((dx * totalDx + dy * totalDy) / 
                 (totalDx * totalDx + totalDy * totalDy)).clamp(0.0, 1.0);
          }

          // Interpolar color
          final color = _interpolateGradientColor(gradientColors, t);
          
          background.setPixel(x, y, img.ColorRgba8(
            color.red,
            color.green,
            color.blue,
            255,
          ));
        }
      }

      // Componer: fondo gradiente + imagen con transparencia
      img.compositeImage(background, originalImage);

      // Codificar a PNG
      final Uint8List result = Uint8List.fromList(img.encodePng(background));
      
      debugPrint('[CustomBackground] ✓ Fondo gradiente aplicado (${gradientColors.length} colores)');
      return result;
    } catch (e) {
      debugPrint('[CustomBackground] ❌ Error al agregar gradiente: $e');
      return null;
    }
  }

  /// Interpola colores en un gradiente según el parámetro t (0.0 - 1.0)
  static Color _interpolateGradientColor(List<Color> colors, double t) {
    if (colors.length == 1) return colors.first;
    if (t <= 0.0) return colors.first;
    if (t >= 1.0) return colors.last;

    // Calcular segmento del gradiente
    final segmentCount = colors.length - 1;
    final segment = (t * segmentCount).floor();
    final nextSegment = (segment + 1).clamp(0, colors.length - 1);
    final localT = (t * segmentCount) - segment;

    // Interpolar entre dos colores adyacentes
    final color1 = colors[segment];
    final color2 = colors[nextSegment];

    return Color.fromARGB(
      ((1 - localT) * color1.alpha + localT * color2.alpha).round(),
      ((1 - localT) * color1.red + localT * color2.red).round(),
      ((1 - localT) * color1.green + localT * color2.green).round(),
      ((1 - localT) * color1.blue + localT * color2.blue).round(),
    );
  }

  /// Fondos predefinidos comunes para credenciales escolares
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundLightGray = Color(0xFFF5F5F5);
  static const Color backgroundLightBlue = Color(0xFFE3F2FD);
  static const Color backgroundCream = Color(0xFFFFFBE6);
  
  /// Gradientes predefinidos
  static const List<Color> gradientProfessionalBlue = [
    Color(0xFFE3F2FD), // Light blue
    Color(0xFFBBDEFB), // Lighter blue
  ];
  
  static const List<Color> gradientSchoolGray = [
    Color(0xFFF5F5F5), // Light gray
    Color(0xFFEEEEEE), // Slightly darker gray
  ];
  
  static const List<Color> gradientWarmCream = [
    Color(0xFFFFFBE6), // Cream
    Color(0xFFFFF9C4), // Light yellow
  ];
}
