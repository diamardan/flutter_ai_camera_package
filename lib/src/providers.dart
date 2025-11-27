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
/// Usa Local Rembg (preciso, 5-7 segundos)
final datamexRemoveBackgroundProvider = StateProvider<bool>((ref) => true);

/// Processing state provider (para el preview)
/// Indica si la imagen está siendo procesada (removiendo fondo)
final datamexProcessingProvider = StateProvider<bool>((ref) => false);

/// Edge blur intensity provider
/// Controla la intensidad del difuminado de bordes al remover fondo
/// Valores: 0 (sin difuminado) a 10 (máximo difuminado)
/// Default: 10 (difuminado máximo)
final datamexEdgeBlurIntensityProvider = StateProvider<double>((ref) => 10.0);

/// Connectivity stream provider
final datamexConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);
