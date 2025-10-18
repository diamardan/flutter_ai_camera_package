export 'providers/capture_state_provider.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Image state provider
final datamexImageProvider = StateProvider<File?>((ref) => null);

/// Loading state provider
final datamexLoadingProvider = StateProvider<bool>((ref) => false);

/// Status message provider
final datamexStatusProvider = StateProvider<String>((ref) => '');

/// Face detection enabled provider
final datamexFaceDetectionEnabledProvider = StateProvider<bool>((ref) => false);

/// Remove background enabled provider
/// Control centralizado para activar/desactivar la remoción de fondo
final datamexRemoveBackgroundProvider = StateProvider<bool>((ref) => true);

/// Processing state provider (para el preview)
/// Indica si la imagen está siendo procesada (removiendo fondo)
final datamexProcessingProvider = StateProvider<bool>((ref) => false);

/// Edge blur intensity provider
/// Controla la intensidad del difuminado de bordes al remover fondo
/// Valores: 0 (sin difuminado) a 10 (máximo difuminado)
/// Default: 3 (difuminado suave)
final datamexEdgeBlurIntensityProvider = StateProvider<double>((ref) => 3.0);

/// Background removal method provider
/// Controla qué método usar para remover el fondo
/// true = ML Kit (más rápido, solo personas)
/// false = Local Rembg (más preciso, cualquier objeto)
/// Default: false (Local Rembg)
final datamexUseMlKitForBackgroundProvider = StateProvider<bool>((ref) => false);

/// Connectivity stream provider
final datamexConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);
