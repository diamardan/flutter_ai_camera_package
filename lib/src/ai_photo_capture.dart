library ai_photo_capture;

export 'ui/photo_capture_screen.dart';
export 'camera/face_detector.dart';
export 'camera/lighting_validator.dart';
export 'camera/accessory_detector.dart';
export 'crop/face_cropper.dart';
export 'providers/capture_state_provider.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';

/// Provides a preconfigured GoRouter with guidelines, camera overlay and preview routes.
GoRouter buildDatamexCameraRouter() {
	return GoRouter(
		routes: [
			datamexGuidelinesRoute(path: '/datamex-guidelines', name: 'datamexGuidelines'),
			datamexOverlayRoute(path: '/datamex-camera-overlay', name: 'datamexCameraOverlay'),
			datamexPreviewRoute(path: '/datamex-photo-preview', name: 'datamexPhotoPreview'),
		],
	);
}
