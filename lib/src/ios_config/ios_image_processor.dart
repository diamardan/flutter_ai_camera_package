import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// iOS-specific processor for camera frames. Builds an InputImage or returns null
/// when the frame bytes appear invalid. This helps avoid MLKInvalidImage due to
/// nil buffers on some devices/frames.
class IOSImageProcessor {
  /// Attempts to create an InputImage from a BGRA8888 camera image.
  /// Returns null if bytes are empty or appear invalid.
  static InputImage? tryCreateFromBGRA(CameraImage image, InputImageRotation rotation) {
    try {
      if (image.planes.isEmpty) return null;
      final plane = image.planes.first;
      final bytes = plane.bytes;
      if (bytes.isEmpty) return null;

  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      );

      // Defensive: ensure bytes length matches expected stride * height (approx)
      final expected = plane.bytesPerRow * image.height;
      if (bytes.length < (expected * 0.6)) {
        // too small to be valid; skip frame
        return null;
      }

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      return null;
    }
  }
}
