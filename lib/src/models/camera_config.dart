import 'package:flutter/material.dart';

/// Configuración de textos personalizables para el paquete.
/// Permite que la app host provea traducciones o customización de mensajes.
class CameraTexts {
  // Textos de la pantalla de captura (overlay)
  final String noFaceDetected;
  final String placeYourFace;
  final String moveCloser;
  final String moveAway;
  final String lookForward;
  final String preparing;
  final String capturing;
  final String centerYourFace;
  final String centerYourHead;
  final String preparingFinalCapture;
  
  // Mensajes de iluminación
  final String tooMuchLight;
  final String notEnoughLight;
  final String improveAmbientLighting;
  final String moveAwayFromDirectLight;
  final String avoidDirectLight;
  final String findBrighterPlace;
  final String needMoreLight;
  final String findDarkerPlace;
  
  // Mensajes de error
  final String noCameraAvailable;
  final String errorInitializingCamera;
  final String errorCapturingImage;
  final String errorLoadingImage;
  
  // Mensajes de procesamiento
  final String processingImage;
  final String removingBackground;
  final String imageProcessed;
  final String thisMayTakeSeconds;
  
  // Pantalla de preview
  final String preview;
  final String photoLooksGood;
  final String takeAnother;
  final String useThisPhoto;
  final String retryPhoto;
  final String acceptPhoto;
  final String noImage;
  
  const CameraTexts({
    // Overlay
    this.noFaceDetected = '❌ No se detecta rostro',
    this.placeYourFace = '🎯 Coloca tu rostro en el óvalo y permanece quieto',
    this.moveCloser = '📏 Acércate un poco',
    this.moveAway = '📏 Aléjate un poco',
    this.lookForward = '👀 Mira al frente',
    this.preparing = '✅ Preparando...',
    this.capturing = '📸 Capturando...',
    this.centerYourFace = '🎯 Mantén tu rostro centrado',
    this.centerYourHead = '🎯 Ahora centra toda tu cabeza',
    this.preparingFinalCapture = '📸 Preparando captura final...',
    
    // Iluminación
    this.tooMuchLight = 'Demasiada luz',
    this.notEnoughLight = 'Necesitas más luz',
    this.improveAmbientLighting = 'Mejora la iluminación del ambiente',
    this.moveAwayFromDirectLight = 'Hay zonas muy brillantes. Aléjate de la luz directa',
    this.avoidDirectLight = 'Evita la luz directa en tu rostro',
    this.findBrighterPlace = 'Busca un lugar con más iluminación',
    this.needMoreLight = 'Necesitas más luz',
    this.findDarkerPlace = 'Demasiada luz, busca un lugar con menos iluminación',
    
    // Errores
    this.noCameraAvailable = 'No hay cámaras disponibles',
    this.errorInitializingCamera = 'Error al inicializar la cámara',
    this.errorCapturingImage = 'Error al capturar la imagen',
    this.errorLoadingImage = 'Error al cargar la imagen',
    
    // Procesamiento
    this.processingImage = 'Procesando imagen...',
    this.removingBackground = 'Eliminando fondo...',
    this.imageProcessed = '✅ Imagen procesada',
    this.thisMayTakeSeconds = 'Esto puede tardar unos segundos',
    
    // Preview
    this.preview = 'Previsualización',
    this.photoLooksGood = '¿La foto se ve bien?',
    this.takeAnother = 'Tomar otra',
    this.useThisPhoto = 'Usar esta foto',
    this.retryPhoto = 'Reintentar foto',
    this.acceptPhoto = 'Aceptar foto',
    this.noImage = 'No hay imagen',
  });

  /// Factory para crear textos en inglés (ejemplo)
  factory CameraTexts.english() => const CameraTexts(
    noFaceDetected: '❌ No face detected',
    placeYourFace: '🎯 Place your face in the oval and stay still',
    moveCloser: '📏 Move closer',
    moveAway: '📏 Move away',
    lookForward: '👀 Look forward',
    preparing: '✅ Preparing...',
    capturing: '📸 Capturing...',
    centerYourFace: '🎯 Keep your face centered',
    centerYourHead: '🎯 Now center your whole head',
    preparingFinalCapture: '📸 Preparing final capture...',
    tooMuchLight: 'Too much light',
    notEnoughLight: 'Need more light',
    improveAmbientLighting: 'Improve ambient lighting',
    moveAwayFromDirectLight: 'Very bright areas. Move away from direct light',
    avoidDirectLight: 'Avoid direct light on your face',
    findBrighterPlace: 'Find a brighter place',
    needMoreLight: 'Need more light',
    findDarkerPlace: 'Too much light, find a darker place',
    noCameraAvailable: 'No cameras available',
    errorInitializingCamera: 'Error initializing camera',
    errorCapturingImage: 'Error capturing image',
    errorLoadingImage: 'Error loading image',
    processingImage: 'Processing image...',
    removingBackground: 'Removing background...',
    imageProcessed: '✅ Image processed',
    thisMayTakeSeconds: 'This may take a few seconds',
    preview: 'Preview',
    photoLooksGood: 'Does the photo look good?',
    takeAnother: 'Take another',
    useThisPhoto: 'Use this photo',
    retryPhoto: 'Retry photo',
    acceptPhoto: 'Accept photo',
    noImage: 'No image',
  );
}

/// Configuración de colores personalizables para el paquete.
/// Permite que la app host sobrescriba colores específicos.
class CameraColors {
  final Color? overlayColor;
  final Color? progressColor;
  final Color? errorColor;
  final Color? successColor;
  final Color? textColor;
  final Color? backgroundColor;
  
  const CameraColors({
    this.overlayColor,
    this.progressColor,
    this.errorColor,
    this.successColor,
    this.textColor,
    this.backgroundColor,
  });
  
  /// Resuelve el color efectivo usando el theme si no se provee uno custom
  Color resolveOverlay(ColorScheme scheme) => 
    overlayColor ?? scheme.primary.withOpacity(0.7);
    
  Color resolveProgress(ColorScheme scheme) => 
    progressColor ?? scheme.secondary;
    
  Color resolveError(ColorScheme scheme) => 
    errorColor ?? scheme.error;
    
  Color resolveSuccess(ColorScheme scheme) => 
    successColor ?? Colors.green;
    
  Color resolveText(ColorScheme scheme) => 
    textColor ?? scheme.onSurface;
    
  Color resolveBackground(ColorScheme scheme) => 
    backgroundColor ?? scheme.surface;
}

/// Configuración completa del widget de cámara.
/// Combina textos y colores personalizables.
class CameraConfig {
  final CameraTexts texts;
  final CameraColors colors;
  
  const CameraConfig({
    this.texts = const CameraTexts(),
    this.colors = const CameraColors(),
  });
  
  /// Factory para configuración en inglés
  factory CameraConfig.english() => CameraConfig(
    texts: CameraTexts.english(),
  );
  
  /// Factory para configuración custom (ej: desde flutter_localizations del host)
  factory CameraConfig.custom({
    required CameraTexts texts,
    CameraColors colors = const CameraColors(),
  }) => CameraConfig(texts: texts, colors: colors);
}
