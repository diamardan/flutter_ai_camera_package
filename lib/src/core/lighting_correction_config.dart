/// Configuración global para corrección de iluminación
/// Define límites seguros para evitar sobre-exposición
class LightingCorrectionConfig {
  /// Máximo ajuste de brillo permitido (±0.15 = ±15%)
  static const double maxBrightnessAdjustment = 0.15;
  
  /// Máximo ajuste de contraste permitido
  static const double maxContrastAdjustment = 1.25;
  
  /// Mínimo ajuste de contraste permitido
  static const double minContrastAdjustment = 0.85;
  
  /// Gamma para oscurecer imágenes muy brillantes (< 1.0 oscurece)
  static const double darkGamma = 0.90;
  
  /// Gamma para aclarar imágenes oscuras (> 1.0 aclara)
  static const double brightGamma = 1.15;
  
  /// Umbral para decidir si una imagen es "segura" para corregir
  /// Si brightness está fuera de este rango, NO aplicar corrección automática
  static const double safeMinBrightness = 0.25;
  static const double safeMaxBrightness = 0.75;
  
  /// Calidad JPEG después de corrección
  static const int jpegQuality = 95;
}
