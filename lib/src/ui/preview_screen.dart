import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class DatamexPhotoPreviewScreen extends StatefulWidget {
  final File file;

  const DatamexPhotoPreviewScreen({super.key, required this.file});

  @override
  State<DatamexPhotoPreviewScreen> createState() => _DatamexPhotoPreviewScreenState();
}

class _DatamexPhotoPreviewScreenState extends State<DatamexPhotoPreviewScreen> {
  Uint8List? _imageBytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      print('[Preview] Loading image bytes...');
      final bytes = await widget.file.readAsBytes();
      print('[Preview] Loaded ${bytes.length} bytes');
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      print('[Preview] Error loading image: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[Preview] File path: ${widget.file.path}');
    print('[Preview] File exists: ${widget.file.existsSync()}');
    print('[Preview] File size: ${widget.file.existsSync() ? widget.file.lengthSync() : 0} bytes');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Previsualización'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.black)))
                    : _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            fit: BoxFit.contain,
                          )
                        : const Center(child: Text('No image', style: TextStyle(color: Colors.black))),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black54),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Reintentar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Usar esta foto'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
