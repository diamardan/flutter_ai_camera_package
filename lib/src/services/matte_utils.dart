import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

/// Utilidades para "mattear" (aplanar) imágenes con transparencia sobre un color sólido
class MatteUtils {
  /// Aplana la transparencia de [decoded] sobre [bgColor] y devuelve JPG (quality configurable)
  static Uint8List flattenToColorJpg(
    img.Image decoded, {
    img.ColorRgba8? bgColor,
    int quality = 90,
  }) {
    debugPrint('[MatteUtils] Iniciando flatten: ${decoded.width}x${decoded.height}');
    final color = bgColor ?? img.ColorRgba8(255, 255, 255, 255);
    debugPrint('[MatteUtils] Color de fondo: R=${color.r} G=${color.g} B=${color.b} A=${color.a}');
    
    final bg = img.Image(width: decoded.width, height: decoded.height);
    img.fill(bg, color: color);

  final int br = color.r.toInt();
  final int bgc = color.g.toInt();
  final int bb = color.b.toInt();
  
    int opaqueCount = 0;
    int semiTransparentCount = 0;
    int transparentCount = 0;

    // Blending manual pixel-a-pixel respetando alpha sin premultiplicación
    for (int y = 0; y < decoded.height; y++) {
      for (int x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        final double a = p.a / 255.0;
        
        if (a >= 1.0) {
          // Píxel completamente opaco: usar color original directo
          opaqueCount++;
          bg.setPixel(x, y, img.ColorRgba8(
            p.r.toInt().clamp(0, 255),
            p.g.toInt().clamp(0, 255),
            p.b.toInt().clamp(0, 255),
            255,
          ));
        } else if (a > 0.0) {
          // Píxel semi-transparente: blending estándar (NO premultiplicado)
          semiTransparentCount++;
          final int sr = p.r.toInt().clamp(0, 255);
          final int sg = p.g.toInt().clamp(0, 255);
          final int sb = p.b.toInt().clamp(0, 255);
          
          final int outR = ((1 - a) * br + a * sr).round().clamp(0, 255);
          final int outG = ((1 - a) * bgc + a * sg).round().clamp(0, 255);
          final int outB = ((1 - a) * bb + a * sb).round().clamp(0, 255);
          
          bg.setPixel(x, y, img.ColorRgba8(outR, outG, outB, 255));
        } else {
          // Transparente total
          transparentCount++;
        }
        // else: a == 0 (transparente) → ya tiene el fondo blanco del fill
      }
    }

    debugPrint('[MatteUtils] Píxeles: opacos=$opaqueCount, semi=$semiTransparentCount, trans=$transparentCount');
    final result = Uint8List.fromList(img.encodeJpg(bg, quality: quality));
    debugPrint('[MatteUtils] JPG generado: ${result.length} bytes');
    return result;
  }

  /// Versión que recibe bytes (PNG con alpha) y regresa bytes JPG
  static Uint8List flattenBytesToColorJpg(
    Uint8List bytes, {
    img.ColorRgba8? bgColor,
    int quality = 90,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    return flattenToColorJpg(
      decoded,
      bgColor: bgColor ?? img.ColorRgba8(255, 255, 255, 255),
      quality: quality,
    );
  }
}
