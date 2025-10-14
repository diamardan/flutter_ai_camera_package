import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../camera/overlay_painter.dart';
import '../providers/capture_state_provider.dart';

class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureStateProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Placeholder for camera preview
          const Center(child: Text('Camera preview placeholder', style: TextStyle(color: Colors.white))),
          // Overlay painter
          IgnorePointer(
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: OvalOverlayPainter(),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(state.message, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop<File?>(null);
                  },
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
