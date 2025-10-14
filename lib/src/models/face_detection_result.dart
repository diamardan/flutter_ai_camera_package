import 'package:flutter/material.dart';

/// Result of face detection analysis
class FaceDetectionResult {
  final bool faceDetected;
  final bool faceCentered;
  final bool faceInFrame;
  final bool properDistance;
  final String message;
  final Rect? faceBounds;
  /// Normalized bounding box relative to the source image (left, top, width, height) in 0..1
  final Rect? normalizedFaceBounds;
  /// Normalized center of the face in 0..1 coordinates (x,y)
  final Offset? normalizedCenter;
  /// Face height as fraction of image height (0..1)
  final double? normalizedFaceHeight;
  final double? confidence;
  // Optional face orientation and expression metrics from ML Kit (degrees / 0..1)
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
  final double? headEulerAngleX;
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  /// Normalized facial landmarks (0..1) using image coordinates
  final List<Offset>? normalizedLandmarks;
  /// Normalized facial contours (0..1) keyed by name (e.g., 'face', 'leftEye', ...)
  final Map<String, List<Offset>>? normalizedContours;

  const FaceDetectionResult({
    required this.faceDetected,
    required this.faceCentered,
    required this.faceInFrame,
    required this.properDistance,
    required this.message,
    this.faceBounds,
    this.normalizedFaceBounds,
    this.normalizedCenter,
    this.normalizedFaceHeight,
    this.confidence,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.headEulerAngleX,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.normalizedLandmarks,
    this.normalizedContours,
  });

  bool get isValid => faceDetected && faceCentered && faceInFrame && properDistance;

  factory FaceDetectionResult.empty() {
    return FaceDetectionResult(
      faceDetected: false,
      faceCentered: false,
      faceInFrame: false,
      properDistance: false,
      message: 'Buscando rostro...',
      faceBounds: null,
      normalizedFaceBounds: null,
      normalizedCenter: null,
      normalizedFaceHeight: 0,
      confidence: 0,
      headEulerAngleY: null,
      headEulerAngleZ: null,
      headEulerAngleX: null,
      smilingProbability: null,
      leftEyeOpenProbability: null,
      rightEyeOpenProbability: null,
      normalizedLandmarks: const [],
      normalizedContours: const {},
    );
  }
}
