/// Resultado del análisis de iluminación de una imagen
class LightingAnalysis {
  /// Brillo promedio normalizado (0.0 = negro, 1.0 = blanco)
  final double averageBrightness;
  
  /// Contraste de la imagen (desviación estándar del brillo)
  final double contrast;
  
  /// Estado de la iluminación
  final LightingState state;
  
  /// Mensaje para el usuario (si hay problema)
  final String? userMessage;
  
  /// Si la foto es aceptable con la iluminación actual
  final bool isAcceptable;
  
  /// Si se puede corregir automáticamente
  final bool canAutoCorrect;

  const LightingAnalysis({
    required this.averageBrightness,
    required this.contrast,
    required this.state,
    this.userMessage,
    required this.isAcceptable,
    required this.canAutoCorrect,
  });

  @override
  String toString() {
    return 'LightingAnalysis(brightness: ${averageBrightness.toStringAsFixed(2)}, '
        'state: $state, acceptable: $isAcceptable, canCorrect: $canAutoCorrect)';
  }
}

/// Estados posibles de iluminación
enum LightingState {
  /// Iluminación perfecta
  optimal,
  
  /// Un poco oscuro pero aceptable
  slightlyDark,
  
  /// Muy oscuro, se recomienda más luz
  tooDark,
  
  /// Extremadamente oscuro, no se puede capturar
  extremelyDark,
  
  /// Un poco brillante pero aceptable
  slightlyBright,
  
  /// Muy brillante, se recomienda menos luz
  tooBright,
  
  /// Extremadamente brillante, sobreexpuesto
  extremelyBright,
}

/// Parámetros configurables para el análisis de iluminación
class LightingThresholds {
  /// Brillo mínimo aceptable sin avisos (0.0-1.0)
  final double minOptimal;
  
  /// Brillo máximo aceptable sin avisos (0.0-1.0)
  final double maxOptimal;
  
  /// Brillo mínimo para captura (por debajo se rechaza)
  final double minAcceptable;
  
  /// Brillo máximo para captura (por encima se rechaza)
  final double maxAcceptable;
  
  /// Contraste mínimo (para detectar imágenes planas)
  final double minContrast;

  const LightingThresholds({
    this.minOptimal = 0.35,      // Por debajo, mostrar aviso "más luz"
    this.maxOptimal = 0.75,      // Por encima, mostrar aviso "menos luz"
    this.minAcceptable = 0.20,   // Por debajo, bloquear captura
    this.maxAcceptable = 0.90,   // Por encima, bloquear captura
    this.minContrast = 0.10,     // Contraste mínimo aceptable
  });

  /// Thresholds por defecto
  static const LightingThresholds defaults = LightingThresholds();
  
  /// Thresholds más estrictos (para mejor calidad)
  static const LightingThresholds strict = LightingThresholds(
    minOptimal: 0.40,
    maxOptimal: 0.70,
    minAcceptable: 0.25,
    maxAcceptable: 0.85,
    minContrast: 0.12,
  );
  
  /// Thresholds más permisivos
  static const LightingThresholds lenient = LightingThresholds(
    minOptimal: 0.30,
    maxOptimal: 0.80,
    minAcceptable: 0.15,
    maxAcceptable: 0.95,
    minContrast: 0.08,
  );
}
