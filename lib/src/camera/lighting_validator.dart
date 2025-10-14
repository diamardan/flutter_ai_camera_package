import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';

class LightingResult {
  final bool ok;
  final double luminance; // 0..1

  LightingResult({required this.ok, this.luminance = 0});
}

abstract class LightingValidator {
  /// Analyze from an image file (legacy/support)
  Future<LightingResult> analyze(File image);

  /// Analyze directly from a camera frame. Implementations should be fast
  /// and operate on the Y (luma) plane when possible.
  Future<LightingResult> analyzeFromCameraImage(CameraImage image);

  void dispose() {}
}

class StubLightingValidator implements LightingValidator {
  @override
  Future<LightingResult> analyze(File image) async {
    return LightingResult(ok: true, luminance: 0.5);
  }

  @override
  Future<LightingResult> analyzeFromCameraImage(CameraImage image) async {
    return LightingResult(ok: true, luminance: 0.5);
  }

  @override
  void dispose() {}
}

/// A simple, fast lighting validator that computes average luminance from
/// the camera image's Y plane. Works for common image formats (NV21/NV12/NV16)
class SimpleLightingValidator implements LightingValidator {
  final double threshold; // threshold in 0..1 for considering lighting OK

  SimpleLightingValidator({this.threshold = 0.25});

  @override
  Future<LightingResult> analyze(File image) async {
    // Fallback for file-based analysis: not implemented here.
    return LightingResult(ok: true, luminance: 0.5);
  }

  @override
  Future<LightingResult> analyzeFromCameraImage(CameraImage image) async {
    try {
      if (image.planes.isEmpty) return LightingResult(ok: false, luminance: 0);

      // The first plane contains Y (luminance) for NV21/NV12 formats.
      final Uint8List bytes = image.planes[0].bytes;
      if (bytes.isEmpty) return LightingResult(ok: false, luminance: 0);

      // To keep it fast, sample every Nth byte if image is large.
      const int step = 4; // tune for performance/accuracy
      int sum = 0;
      int count = 0;
      for (int i = 0; i < bytes.length; i += step) {
        sum += bytes[i];
        count++;
      }

      final avg = count > 0 ? (sum / count) : 0.0;

      // Y values are 0..255. Normalize to 0..1
      final luminance = (avg / 255.0).clamp(0.0, 1.0);

      final ok = luminance >= threshold;
      return LightingResult(ok: ok, luminance: luminance);
    } catch (e) {
      return LightingResult(ok: false, luminance: 0);
    }
  }

  @override
  void dispose() {}
}
