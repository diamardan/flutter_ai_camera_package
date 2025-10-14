# 📸 Datamex Camera Package

Enhanced camera widget package with **AI-powered face detection** for Flutter applications.

## ✨ Features

- 🤖 **AI Face Detection** using Google ML Kit
- 🎯 Real-time face positioning guidance
- 📱 Automatic capture when face is properly positioned
- 🔄 Works with Riverpod state management
- 🚀 go_router integration ready
- 📷 Camera and gallery support
- 🔐 Proper permission handling
- 🌐 Server photo preview support
- 🎨 Modern, customizable UI

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  datamex_camera_package:
    path: packages/datamex_camera_package
```

Then run:
```bash
flutter pub get
```

## 🔧 Platform Configuration

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
    android:maxSdkVersion="32" />

<application>
    <meta-data
        android:name="com.google.mlkit.vision.DEPENDENCIES"
        android:value="face" />
</application>
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para tomar fotos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Necesitamos acceso a la galería para seleccionar fotos</string>
```

## 🚀 Usage

### Basic Usage

```dart
import 'package:datamex_camera_package/datamex_camera_package.dart';

DatamexCameraWidget(
  onImageSelected: (File? image) {
    if (image != null) {
      print('Image selected: ${image.path}');
    }
  },
  loadStatusCallback: (bool loading) {
    print('Loading: $loading');
  },
  changeStatusMessageCallback: (String msg) {
    print('Status: $msg');
  },
)
```

### With AI Face Detection

```dart
DatamexCameraWidget(
  useFaceDetection: true,  // Enable AI face detection
  showOverlay: true,       // Use fullscreen camera
  startsWithSelfieCamera: true,  // Use front camera
  onImageSelected: (File? image) {
    // Handle captured image with verified face position
  },
  loadStatusCallback: (bool loading) {},
  changeStatusMessageCallback: (String msg) {},
)
```

### With Custom State Provider

```dart
final myImageProvider = StateProvider<File?>((ref) => null);

DatamexCameraWidget(
  imageProvider: myImageProvider,  // Use your own provider
  useFaceDetection: true,
  onImageSelected: (File? image) {},
  loadStatusCallback: (bool loading) {},
  changeStatusMessageCallback: (String msg) {},
)
```

### All Options

```dart
DatamexCameraWidget(
  // Required callbacks
  onImageSelected: (File? image) {},
  loadStatusCallback: (bool loading) {},
  changeStatusMessageCallback: (String msg) {},
  
  // Optional parameters
  imageProvider: myCustomProvider,           // Custom Riverpod provider
  showOverlay: true,                         // Fullscreen camera mode
  useFaceDetection: true,                    // Enable AI face detection
  removeBackground: false,                   // Background removal (stub)
  acceptChooseImageFromGallery: true,        // Show gallery button
  handleServerPhoto: true,                   // Server photo support
  serverPhotoId: 'photo_123',               // Server photo ID
  serverBaseUrl: 'https://api.example.com', // API base URL
  startsWithSelfieCamera: true,             // Use front camera
  placeHolderMessage: 'Tap to take photo',  // Custom placeholder
)
```

## 🛣️ go_router Integration

```dart
import 'package:datamex_camera_package/datamex_camera_package.dart';

final router = GoRouter(
  routes: [
    // ... your other routes
    
    // Add camera overlay route
    datamexOverlayRoute(
      path: '/camera',
      name: 'camera',
      useFaceDetection: true,  // Enable AI
    ),
  ],
);

// Use it in your app
final File? capturedImage = await context.push<File?>('/camera');
```

## 🧠 Face Detection Features

When `useFaceDetection: true`:

1. ✅ **Real-time face detection** - Detects faces in camera feed
2. 🎯 **Positioning guidance** - Shows on-screen instructions
3. 📏 **Distance validation** - Ensures proper face size
4. 🎪 **Centering detection** - Verifies face is centered
5. ⚡ **Auto-capture** - Captures when position is perfect
6. 📊 **Visual feedback** - Green overlay when ready

### Face Detection Messages

- ❌ "No se detecta rostro" - No face found
- ⚠️ "Se detectan múltiples rostros" - Multiple faces
- ⚠️ "Acércate más a la cámara" - Too far
- ⚠️ "Aléjate un poco de la cámara" - Too close
- ⬅️➡️⬆️⬇️ Directional guidance
- ✅ "Perfecto! Mantén la posición" - Ready to capture

## 📚 Exported Components

```dart
// Main widget
export 'src/datamex_camera_widget.dart';

// Providers
export 'src/providers.dart';

// Routing
export 'src/routes.dart';

// Overlay screen
export 'src/overlay_screen.dart';

// Face detection components
export 'src/widgets/face_detection_camera.dart';
export 'src/services/face_detection_service.dart';
export 'src/models/face_detection_result.dart';
```

## 🔍 Available Providers

```dart
// Image state
final datamexImageProvider = StateProvider<File?>((ref) => null);

// Loading state
final datamexLoadingProvider = StateProvider<bool>((ref) => false);

// Status messages
final datamexStatusProvider = StateProvider<String>((ref) => '');

// Face detection toggle
final datamexFaceDetectionEnabledProvider = StateProvider<bool>((ref) => false);

// Connectivity monitoring
final datamexConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);
```

## 🎨 Customization

The widget uses Material Design and adapts to your app's theme. You can customize:

- Button styles through ThemeData
- Placeholder messages via `placeHolderMessage` parameter
- Face detection overlay colors (edit `FaceDetectionPainter`)

## 🐛 Troubleshooting

### Face detection not working
- Ensure camera permissions are granted
- Check that ML Kit dependencies are configured in AndroidManifest.xml
- Verify minimum SDK version (Android 21+)

### Build errors
```bash
flutter clean
flutter pub get
cd ios && pod install  # iOS only
flutter run
```

### Permission issues
- Check Info.plist (iOS) and AndroidManifest.xml (Android)
- Test with `adb logcat` (Android) or Xcode console (iOS)

## 📄 License

This is a private package for internal use.

## 🤝 Contributing

This package is maintained internally. For issues or feature requests, contact the development team.

---

**Version:** 1.0.0  
**Flutter:** >=3.10.0  
**Dart:** >=3.0.0 <4.0.0
