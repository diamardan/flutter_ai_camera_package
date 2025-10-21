library itc_camera_package;

export 'src/datamex_camera_widget.dart';
export 'src/providers.dart';
export 'src/routes.dart';
export 'src/overlay_screen.dart';
export 'src/widgets/face_detection_camera_simple.dart';
export 'src/widgets/lottie_animation_widget.dart';
export 'src/services/face_detection_service.dart';
export 'src/services/lighting_validator.dart';
export 'src/models/camera_config.dart'; // ✅ Exportar configuración
export 'src/services/lighting_corrector.dart';
export 'src/services/edge_refinement_service.dart';
export 'src/services/mlkit_background_removal.dart';
export 'src/services/custom_background_service.dart'; // Fondos personalizados
export 'src/models/face_detection_result.dart';
export 'src/models/guideline_entry.dart';
export 'src/models/lighting_analysis.dart';

// 🐛 Debug utilities (for troubleshooting device-specific issues)
export 'src/utils/debug_logger.dart';
export 'src/ui/debug_log_overlay.dart';
