import 'dart:io';
import 'dart:ui';

/// Stub interface for face detection. Implement with ML Kit or TFLite.
class FaceDetectionResult {
  final bool faceDetected;
  final double yaw; // head rotation
  final double roll;
  final double pitch;
  final double confidence;
  final Rect? boundingBox;

  FaceDetectionResult({
    required this.faceDetected,
    this.yaw = 0,
    this.roll = 0,
    this.pitch = 0,
    this.confidence = 0,
    this.boundingBox,
  });
}

abstract class FaceDetector {
  /// Process an image file and return detection info
  Future<FaceDetectionResult> processImage(File image);

  /// Dispose resources if needed
  void dispose() {}
}

/// A dummy implementation that always returns no face. Replace with real detector.
class StubFaceDetector implements FaceDetector {
  @override
  Future<FaceDetectionResult> processImage(File image) async {
    return FaceDetectionResult(faceDetected: false);
  }

  @override
  void dispose() {
    // no resources
  }
}
