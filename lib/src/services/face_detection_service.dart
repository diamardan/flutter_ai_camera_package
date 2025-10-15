import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/platform_handler.dart';
import '../ios_config/ios_image_processor.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import '../models/face_detection_result.dart';

class FaceDetectionService {
  late FaceDetector _faceDetector;
  bool _isProcessing = false;

  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<FaceDetectionResult?> detectFace(CameraImage image, InputImageRotation rotation, Size screenSize) async {
    // If a frame is already being processed, skip this one to avoid UI flicker
    if (_isProcessing) {
      return null;
    }

    _isProcessing = true;

    try {
      InputImage? inputImage;
      // If running on iOS, attempt the safer BGRA path first to avoid nil CVPixelBuffer issues
      if (PlatformHandler.isIOS) {
        inputImage = IOSImageProcessor.tryCreateFromBGRA(image, rotation);
      }
      inputImage ??= _inputImageFromCameraImage(image, rotation);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

  final faces = await _faceDetector.processImage(inputImage);
      _isProcessing = false;

      if (faces.isEmpty) {
        return const FaceDetectionResult(
          faceDetected: false,
          faceCentered: false,
          faceInFrame: false,
          properDistance: false,
          message: '❌ No se detecta rostro',
        );
      }

      if (faces.length > 1) {
        return const FaceDetectionResult(
          faceDetected: true,
          faceCentered: false,
          faceInFrame: false,
          properDistance: false,
          message: '⚠️ Se detectan múltiples rostros',
        );
      }

  final face = faces.first;
  final faceBounds = face.boundingBox;

      // Determine image size from input image (MLKit coordinates are relative to the input image)
  final imageWidth = image.width.toDouble();
  final imageHeight = image.height.toDouble();

      // Calculate rotated dimensions
      // iOS BGRA: coordinates come in sensor space, use direct dimensions
      // Android YUV: needs dimension swap based on rotation
      final rotatedWidth = PlatformHandler.isIOS 
          ? imageWidth  
          : (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg)
              ? imageHeight
              : imageWidth;
      final rotatedHeight = PlatformHandler.isIOS
          ? imageHeight 
          : (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg)
              ? imageWidth
              : imageHeight;
      
      // Debug logging to verify coordinate mapping
      debugPrint('[FaceDetection] Platform: ${PlatformHandler.isIOS ? "iOS" : "Android"} | Image: ${image.width}×${image.height} | Rotation: $rotation');
      debugPrint('[FaceDetection] Rotated: $rotatedWidth×$rotatedHeight | FaceBounds: ${faceBounds.left.toInt()},${faceBounds.top.toInt()} ${faceBounds.width.toInt()}×${faceBounds.height.toInt()}');

      // Apply coordinate mirroring ONLY for front camera to match the mirrored preview
      // This fixes the issue where face guides move opposite to head movement
      Offset rotatePoint(double x, double y) {
        // Mirror horizontally for front camera (left ↔ right)
        if (PlatformHandler.isIOS) {
          // iOS: mirror X coordinate
          return Offset(imageWidth - x, y);
        }
        // Android: no mirroring needed (already handled elsewhere)
        return Offset(x, y);
      }

      // Rotate and normalize bounding box
      final List<Offset> bbCorners = [
        rotatePoint(faceBounds.left, faceBounds.top),
        rotatePoint(faceBounds.right, faceBounds.top),
        rotatePoint(faceBounds.right, faceBounds.bottom),
        rotatePoint(faceBounds.left, faceBounds.bottom),
      ];
      
      double minX = bbCorners[0].dx, maxX = bbCorners[0].dx;
      double minY = bbCorners[0].dy, maxY = bbCorners[0].dy;
      for (final corner in bbCorners) {
        if (corner.dx < minX) minX = corner.dx;
        if (corner.dx > maxX) maxX = corner.dx;
        if (corner.dy < minY) minY = corner.dy;
        if (corner.dy > maxY) maxY = corner.dy;
      }

      final leftNorm = (minX / rotatedWidth).clamp(0.0, 1.0);
      final topNorm = (minY / rotatedHeight).clamp(0.0, 1.0);
      final widthNorm = ((maxX - minX) / rotatedWidth).clamp(0.0, 1.0);
      final heightNorm = ((maxY - minY) / rotatedHeight).clamp(0.0, 1.0);
      final centerXNorm = (leftNorm + widthNorm / 2).clamp(0.0, 1.0);
      final centerYNorm = (topNorm + heightNorm / 2).clamp(0.0, 1.0);
      
      debugPrint('[FaceDetection] Normalized: L=${leftNorm.toStringAsFixed(3)} T=${topNorm.toStringAsFixed(3)} W=${widthNorm.toStringAsFixed(3)} H=${heightNorm.toStringAsFixed(3)}');

      final normalizedRect = Rect.fromLTWH(leftNorm, topNorm, widthNorm, heightNorm);

      // Face height ratio in upright orientation
      final faceHeightRatio = heightNorm;

      // Landmarks (normalize 0..1) - Apply rotation transform
      final List<Offset> normLandmarks = [];
      for (final entry in face.landmarks.entries) {
        final p = entry.value?.position;
        if (p != null) {
          final rotated = rotatePoint(p.x.toDouble(), p.y.toDouble());
          normLandmarks.add(
            Offset(
              (rotated.dx / rotatedWidth).clamp(0.0, 1.0),
              (rotated.dy / rotatedHeight).clamp(0.0, 1.0),
            ),
          );
        }
      }

      // Contours (normalize 0..1) - Apply rotation transform
      final Map<String, List<Offset>> normContours = {};
      for (final c in face.contours.entries) {
        final points = c.value?.points;
        if (points != null && points.isNotEmpty) {
          normContours[c.key.name] = points
              .map((pt) {
                final rotated = rotatePoint(pt.x.toDouble(), pt.y.toDouble());
                return Offset(
                  (rotated.dx / rotatedWidth).clamp(0.0, 1.0),
                  (rotated.dy / rotatedHeight).clamp(0.0, 1.0),
                );
              })
              .toList(growable: false);
        }
      }

      // For legacy fields, keep faceBounds (absolute) but prefer normalized values for UI mapping
      return FaceDetectionResult(
        faceDetected: true,
        faceCentered: false, // computed in UI layer using normalized center vs preview center
        faceInFrame: true,
        properDistance: faceHeightRatio >= 0.01,
        message: 'Rostro detectado',
        faceBounds: faceBounds,
        normalizedFaceBounds: normalizedRect,
        normalizedCenter: Offset(centerXNorm, centerYNorm),
        normalizedFaceHeight: faceHeightRatio,
        confidence: face.headEulerAngleY != null ? 1.0 : 0.8,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
        headEulerAngleX: face.headEulerAngleX,
        smilingProbability: face.smilingProbability,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        normalizedLandmarks: normLandmarks,
        normalizedContours: normContours,
      );
    } catch (e) {
      _isProcessing = false;
      debugPrint('Error in face detection: $e');
      return FaceDetectionResult.empty();
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, InputImageRotation rotation) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      debugPrint('Error creating InputImage: $e');
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
