import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Widget helper para mostrar animaciones Lottie del paquete
/// Soporta iOS y Android automáticamente
class LottieAnimationWidget extends StatelessWidget {
  /// Nombre del archivo Lottie (sin path ni extensión)
  /// Ejemplo: 'clear-face' cargará 'assets/lotties/clear-face.json'
  final String animationName;
  
  /// Ancho de la animación (opcional)
  final double? width;
  
  /// Alto de la animación (opcional)
  final double? height;
  
  /// BoxFit para la animación
  final BoxFit? fit;
  
  /// Si la animación debe repetirse infinitamente
  final bool repeat;
  
  /// Si la animación debe reproducirse en reversa después de completarse
  final bool reverse;
  
  /// Controlador personalizado para controlar la animación (opcional)
  final AnimationController? controller;
  
  /// Callback cuando la animación se carga
  final LottieDelegates? delegates;

  const LottieAnimationWidget({
    super.key,
    required this.animationName,
    this.width,
    this.height,
    this.fit,
    this.repeat = true,
    this.reverse = false,
    this.controller,
    this.delegates,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'packages/itc_camera_package/assets/lotties/$animationName.json',
      width: width,
      height: height,
      fit: fit ?? BoxFit.contain,
      repeat: repeat,
      reverse: reverse,
      controller: controller,
      delegates: delegates,
      errorBuilder: (context, error, stackTrace) {
        // Fallback si el archivo no se encuentra
        debugPrint('[LottieAnimationWidget] Error loading $animationName: $error');
        return Icon(
          Icons.animation,
          size: width ?? height ?? 100,
          color: Colors.grey,
        );
      },
    );
  }
}

/// Animaciones predefinidas disponibles en el paquete
class LottieAnimations {
  /// Animación de rostro limpio/claro
  static const String clearFace = 'clear-face';
  
  // Agregar más animaciones aquí según se vayan añadiendo
  // static const String loading = 'loading';
  // static const String success = 'success';
  // static const String error = 'error';
}

/// Widget específico para la animación de rostro limpio
class ClearFaceLottieWidget extends StatelessWidget {
  final double? size;
  final bool repeat;
  
  const ClearFaceLottieWidget({
    super.key,
    this.size,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    return LottieAnimationWidget(
      animationName: LottieAnimations.clearFace,
      width: size,
      height: size,
      repeat: repeat,
    );
  }
}
