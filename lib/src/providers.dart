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

/// Connectivity stream provider
final datamexConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);
