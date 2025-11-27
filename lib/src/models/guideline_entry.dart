import 'package:flutter/material.dart';

/// Represents a single guideline entry (text + optional custom style).
class GuidelineEntry {
  final String text;
  final TextStyle? style;
  const GuidelineEntry(this.text, {this.style});
}

/// Bundle object passed through navigation extra to Guidelines screen.
class GuidelinesConfig {
  final List<GuidelineEntry> guidelines;
  /// Whether the acceptance checkbox should be rendered.
  final bool showAcceptanceCheckbox;
  /// Current acceptance state (true si el checkbox de lineamientos ya fue aceptado).
  final bool isGuidelinesCheckboxAccepted;
  final bool useFaceDetection;
  final bool startsWithSelfie;
  final bool showOverlay;
  /// Controls showing facial landmarks/contours guides in overlay.
  final bool showFaceGuides;
  /// Show debug logs and overlays
  final bool showDebug;
  /// Edge blur intensity for background removal (0-10)
  final double edgeBlurIntensity;
  /// Use single capture step (fast mode) or multiple steps (2 ovals)
  final bool useSingleCaptureStep;
  
  const GuidelinesConfig({
    required this.guidelines,
    required this.showAcceptanceCheckbox,
    this.isGuidelinesCheckboxAccepted = false,
    required this.useFaceDetection,
    required this.startsWithSelfie,
    required this.showOverlay,
    this.showFaceGuides = true,
    this.showDebug = false,
    this.edgeBlurIntensity = 5.0,
    this.useSingleCaptureStep = false,
  });
}