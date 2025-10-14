import 'dart:io';

class AccessoryDetectionResult {
  final bool hasGlasses;
  final bool hasSunglasses;
  final bool hasMask;
  AccessoryDetectionResult({this.hasGlasses = false, this.hasSunglasses = false, this.hasMask = false});
}

abstract class AccessoryDetector {
  Future<AccessoryDetectionResult> analyze(File image);
  void dispose() {}
}

class StubAccessoryDetector implements AccessoryDetector {
  @override
  Future<AccessoryDetectionResult> analyze(File image) async {
    return AccessoryDetectionResult();
  }

  @override
  void dispose() {}
}
