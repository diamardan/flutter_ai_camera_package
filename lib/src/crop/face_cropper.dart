import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Crops a captured selfie to an ID-style portrait: head + upper shoulders with 3:4 aspect.
class FaceCropper {
  FaceCropper({FaceDetector? faceDetector})
      : _faceDetector = faceDetector ?? FaceDetector(options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: false,
          enableContours: false,
          enableClassification: false,
          minFaceSize: 0.1,
        ));

  final FaceDetector _faceDetector;

  /// Crop to target aspect (default 3:4) around detected face.
  /// Heuristics:
  /// - Adds top headroom and bottom shoulders room relative to face height.
  /// - Centers horizontally on face center.
  /// - Clamps to image bounds, preserving target aspect.
  /// - Applies mild contrast/brightness adjustment.
  Future<File> cropToIdFormat(
    File file, {
    double aspectW = 3,
    double aspectH = 4,
    double topHeadroomFactor = 0.35, // fraction of face height above head
    double bottomShouldersFactor = 0.65, // fraction of face height below chin
    bool applyColorAdjust = true,
    int? outputWidth, // e.g., 900 for 900x1200; if null keeps natural size
  }) async {
    // Decode original and bake EXIF orientation first
    final bytes = await file.readAsBytes();
    final decoded0 = img.decodeImage(bytes);
    if (decoded0 == null) return file;
    final baked = img.bakeOrientation(decoded0);
    double iw = baked.width.toDouble();
    double ih = baked.height.toDouble();

    // Write baked image to a temp file so MLKit reads a canonical orientation
    final tmpDir = await getTemporaryDirectory();
    final bakedPath = '${tmpDir.path}/baked_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(bakedPath).writeAsBytes(img.encodeJpg(baked, quality: 95), flush: true);

    // Detect face on the baked image (coordinates now align with pixels)
    final inputImage = InputImage.fromFilePath(bakedPath);
    final faces = await _faceDetector.processImage(inputImage);
    // Requisito: exactamente 1 rostro. Si no, fallback a center-crop 3:4
    if (faces.length != 1) {
      final fallback = _centerCrop(baked, aspectW / aspectH);
      return _encodeToTemp(fallback);
    }
    var bb = faces.first.boundingBox;
    if (bb.width <= 1 || bb.height <= 1) {
      final fallback = _centerCrop(baked, aspectW / aspectH);
      return _encodeToTemp(fallback);
    }

    // Build initial portrait crop bounds based on heuristics
    final faceH = bb.height;
    final desiredTop = bb.top - (topHeadroomFactor * faceH);
    final desiredBottom = bb.bottom + (bottomShouldersFactor * faceH);
    double cropTop = desiredTop;
    double cropBottom = desiredBottom;
    double cropHeight = cropBottom - cropTop;

    // Compute target width from aspect
    final targetAspect = aspectW / aspectH; // ~0.75 (portrait)
    double cropWidth = cropHeight * targetAspect;
    double cx = bb.left + bb.width / 2; // center horizontally on the face
    double cropLeft = cx - cropWidth / 2;
    double cropRight = cropLeft + cropWidth;

    // Clamp to image bounds; if overflow, adjust and recalc paired axis
    // Horizontal clamp
    if (cropLeft < 0) {
      cropLeft = 0;
      cropRight = cropWidth;
    }
    if (cropRight > iw) {
      cropRight = iw;
      cropLeft = iw - cropWidth;
    }
    // Vertical clamp
    if (cropTop < 0) {
      cropTop = 0;
      cropBottom = cropTop + cropHeight;
    }
    if (cropBottom > ih) {
      cropBottom = ih;
      cropTop = ih - cropHeight;
    }

    // If clamps caused crop to exceed image, shrink proportionally to fit while keeping aspect
    // Width fit
    if (cropLeft < 0 || cropRight > iw) {
      final maxWidth = iw;
      cropWidth = maxWidth;
      cropHeight = cropWidth / targetAspect;
      cx = math.min(math.max(cx, cropWidth / 2), iw - cropWidth / 2);
      cropLeft = cx - cropWidth / 2;
      cropRight = cx + cropWidth / 2;
      // recalc vertical to maintain centered near original top/bottom if possible
      double cy = (cropTop + cropBottom) / 2;
      cy = math.min(math.max(cy, cropHeight / 2), ih - cropHeight / 2);
      cropTop = cy - cropHeight / 2;
      cropBottom = cy + cropHeight / 2;
    }
    // Height fit
    if (cropTop < 0 || cropBottom > ih) {
      final maxHeight = ih;
      cropHeight = maxHeight;
      cropWidth = cropHeight * targetAspect;
      cx = math.min(math.max(cx, cropWidth / 2), iw - cropWidth / 2);
      cropLeft = cx - cropWidth / 2;
      cropRight = cx + cropWidth / 2;
      cropTop = 0;
      cropBottom = cropHeight;
    }

    // Final integer crop box
    int x = cropLeft.clamp(0.0, iw - 1).round();
    int y = cropTop.clamp(0.0, ih - 1).round();
    int w = (cropRight - cropLeft).clamp(1.0, iw - x).round();
    int h = (cropBottom - cropTop).clamp(1.0, ih - y).round();

    // Guard: if computed crop is suspiciously small, fallback to center-crop 3:4
    if (w < 100 || h < 100) {
      final fallbackH = (ih * 0.86).round();
      final fallbackW = (fallbackH * targetAspect).round();
      final fx = ((iw - fallbackW) / 2).round().clamp(0, iw.toInt() - 1);
      final fy = ((ih - fallbackH) / 2).round().clamp(0, ih.toInt() - 1);
      w = math.min(fallbackW, (iw - fx).toInt());
      h = math.min(fallbackH, (ih - fy).toInt());
      x = fx;
      y = fy;
    }

  img.Image out = img.copyCrop(baked, x: x, y: y, width: w, height: h);

    // Mild auto adjust
    if (applyColorAdjust) {
      out = img.adjustColor(out, contrast: 1.06, brightness: 0.02);
    }

    // Optional resize to standard size (e.g., 900x1200)
    if (outputWidth != null && outputWidth > 0) {
      final outputHeight = (outputWidth / targetAspect).round();
      out = img.copyResize(out, width: outputWidth, height: outputHeight, interpolation: img.Interpolation.average);
    }

    // Save to temp file and sanity check
    final outFile = await _encodeToTemp(out);
    try {
      final check = img.decodeImage(await outFile.readAsBytes());
      if (check == null || check.width < 50 || check.height < 50) {
        final fallback = _centerCrop(baked, targetAspect);
        return _encodeToTemp(fallback);
      }
      return outFile;
    } catch (_) {
      final fallback = _centerCrop(baked, targetAspect);
      return _encodeToTemp(fallback);
    }
  }

  /// Simple crop: no detection. Uses full width when possible and trims only top/bottom
  /// to reach the target aspect (default 3:4). Works on baked-orientation image.
  Future<File> cropTopBottomSimple(
    File file, {
    Uint8List? mirroredBytes, // Optional pre-mirrored bytes to avoid file corruption
    double aspectW = 3,
    double aspectH = 4,
    double verticalBias = 0.0, // -0.5..0.5 shifts window up/down; 0.0 centered
    bool applyColorAdjust = true,
    int? outputWidth,
  }) async {
    try {
      final bytes = mirroredBytes ?? await file.readAsBytes();
      print('[Crop] Bytes length: ${bytes.length}');
      
      final decoded0 = img.decodeImage(bytes);
      print('[Crop] Decoded0: ${decoded0 != null ? "${decoded0.width}x${decoded0.height}" : "null"}');
      if (decoded0 == null) {
        print('[Crop] DECODE FAILED - returning original file');
        return file;
      }
      
      // Solo aplicar bakeOrientation si NO son bytes espejados (que ya perdieron EXIF)
      final baked = mirroredBytes != null ? decoded0 : img.bakeOrientation(decoded0);
      print('[Crop] Baked: ${baked.width}x${baked.height}');

      final iw = baked.width.toDouble();
      final ih = baked.height.toDouble();
      final targetAspect = aspectW / aspectH; // ~0.75 portrait
      print('[Crop] Image: ${iw}x$ih, target aspect: $targetAspect');

      // Try to use full width first; compute required height
      double cropW = iw;
      double cropH = cropW / targetAspect; // since aspect = W/H => H = W/aspect
      int x = 0;
      int y;

      if (cropH > ih) {
        // Not enough height to use full width; reduce width to fit height
        cropH = ih;
        cropW = cropH * targetAspect;
        x = ((iw - cropW) / 2).round().clamp(0, iw.toInt() - 1);
      }

      // Vertical position with optional bias
      final freeH = ih - cropH;
      final centerY = freeH / 2.0;
      final biased = centerY + (freeH * verticalBias).clamp(-freeH / 2, freeH / 2);
      y = biased.round().clamp(0, (ih - cropH).toInt());

      final w = cropW.round().clamp(1, (iw - x).toInt());
      final h = cropH.round().clamp(1, (ih - y).toInt());
      print('[Crop] Crop box: x=$x, y=$y, w=$w, h=$h');

      img.Image out = img.copyCrop(baked, x: x, y: y, width: w, height: h);
      print('[Crop] Cropped: ${out.width}x${out.height}');
      
      if (applyColorAdjust) {
        out = img.adjustColor(out, contrast: 1.06, brightness: 0.02);
      }
      if (outputWidth != null && outputWidth > 0) {
        final outputHeight = (outputWidth / targetAspect).round();
        out = img.copyResize(out, width: outputWidth, height: outputHeight, interpolation: img.Interpolation.average);
        print('[Crop] Resized: ${out.width}x${out.height}');
      }
      
      final result = await _encodeToTemp(out);
      print('[Crop] Saved to: ${result.path}');
      return result;
    } catch (e, stack) {
      print('[Crop] ERROR: $e');
      print('[Crop] Stack: $stack');
      return file;
    }
  }

  img.Image _centerCrop(img.Image source, double targetAspect) {
    final iw = source.width.toDouble();
    final ih = source.height.toDouble();
    double h = ih * 0.88;
    double w = h * targetAspect;
    if (w > iw) {
      w = iw * 0.96;
      h = w / targetAspect;
    }
    final cx = iw / 2;
    final cy = ih / 2;
    final left = (cx - w / 2).clamp(0.0, iw - 1).round();
    final top = (cy - h / 2).clamp(0.0, ih - 1).round();
    final width = w.clamp(1.0, iw - left).round();
    final height = h.clamp(1.0, ih - top).round();
    return img.copyCrop(source, x: left, y: top, width: width, height: height);
  }

  Future<File> _encodeToTemp(img.Image im) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/face_crop_${DateTime.now().millisecondsSinceEpoch}.png';
    print('[Crop] Encoding to PNG...');
    final png = img.encodePng(im);
    print('[Crop] PNG encoded: ${png.length} bytes');
    final outFile = File(path);
    await outFile.writeAsBytes(png, flush: true);
    print('[Crop] File written successfully');
    return outFile;
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
