import 'package:go_router/go_router.dart';
import 'overlay_screen.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'ui/preview_screen.dart';
import 'ui/guidelines_screen.dart';
import 'models/guideline_entry.dart';
import 'models/camera_config.dart'; // ✅ Importar configuración

/// Helper to create a GoRoute for the camera overlay.
/// Usage: final file = await context.push<File?>('/datamex-camera-overlay', extra: {'config': cameraConfig});
GoRoute datamexOverlayRoute({
  required String path,
  required String name,
  bool useFaceDetection = false,
}) {
  return GoRoute(
    path: path,
    name: name,
    pageBuilder: (context, state) {
      final qp = state.uri.queryParameters;
      final extra = state.extra;
      bool useFD = useFaceDetection || qp['useFaceDetection'] == 'true';
      bool startsSelfie = false;
      bool showFaceGuides = true;
      CameraConfig config = const CameraConfig();
      // ❌ removeBackground se lee del PROVIDER, no del extra
      if (extra is Map) {
        if (extra['useFaceDetection'] is bool) useFD = extra['useFaceDetection'] as bool;
        if (extra['startsWithSelfie'] is bool) startsSelfie = extra['startsWithSelfie'] as bool;
        if (extra['showFaceGuides'] is bool) showFaceGuides = extra['showFaceGuides'] as bool;
        if (extra['config'] is CameraConfig) config = extra['config'] as CameraConfig;
      }
      return MaterialPage<File?>(
        key: state.pageKey,
        child: DatamexCameraOverlayScreen(
          useFaceDetection: useFD,
          startsWithSelfie: startsSelfie,
          showFaceGuides: showFaceGuides,
          config: config,
          // removeBackground se lee internamente del provider
        ),
      );
    },
  );
}

/// Route for guidelines screen.
GoRoute datamexGuidelinesRoute({
  required String path,
  required String name,
}) {
  return GoRoute(
    path: path,
    name: name,
    pageBuilder: (context, state) {
      final extra = state.extra;
      GuidelinesConfig cfg;
      if (extra is GuidelinesConfig) {
        cfg = extra;
      } else {
        cfg = const GuidelinesConfig(
          guidelines: [],
          showAcceptanceCheckbox: true,
          useFaceDetection: true,
          startsWithSelfie: true,
          showOverlay: true,
          showFaceGuides: true,
        );
      }
      return MaterialPage<void>(
        key: state.pageKey,
        child: GuidelinesScreen(config: cfg),
      );
    },
  );
}

/// Helper to create a GoRoute for the preview screen.
/// Usage: final accepted = await context.push<bool>('/datamex-photo-preview', extra: {'file': file, 'config': config});
GoRoute datamexPreviewRoute({
  required String path,
  required String name,
}) {
  return GoRoute(
    path: path,
    name: name,
    pageBuilder: (context, state) {
      File? file;
      CameraConfig config = const CameraConfig();
      final extra = state.extra;
      if (extra is File) {
        file = extra;
      } else if (extra is Map) {
        if (extra['file'] is File) file = extra['file'] as File;
        if (extra['config'] is CameraConfig) config = extra['config'] as CameraConfig;
      }
      return MaterialPage<bool>(
        key: state.pageKey,
        child: file == null
            ? const Scaffold(body: Center(child: Text('No file to preview')))
            : DatamexPhotoPreviewScreen(file: file, config: config),
      );
    },
  );
}
