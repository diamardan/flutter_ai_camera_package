import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class DatamexPhotoPreviewScreen extends ConsumerStatefulWidget {
  final File file;

  const DatamexPhotoPreviewScreen({super.key, required this.file});

  @override
  ConsumerState<DatamexPhotoPreviewScreen> createState() => _DatamexPhotoPreviewScreenState();
}

class _DatamexPhotoPreviewScreenState extends ConsumerState<DatamexPhotoPreviewScreen> {
  Uint8List? _imageBytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Esperar a que termine el procesamiento antes de cargar
    final isProcessing = ref.read(datamexProcessingProvider);
    if (isProcessing) {
      debugPrint('[Preview] Esperando a que termine el procesamiento...');
      // Esperar hasta que termine
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return ref.read(datamexProcessingProvider);
      });
      debugPrint('[Preview] Procesamiento completado, cargando imagen...');
    }
    
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
    final isProcessing = ref.watch(datamexProcessingProvider);
    final statusMessage = ref.watch(datamexStatusProvider);
    
    print('[Preview] File path: ${widget.file.path}');
    print('[Preview] File exists: ${widget.file.existsSync()}');
    print('[Preview] File size: ${widget.file.existsSync() ? widget.file.lengthSync() : 0} bytes');
    print('[Preview] isProcessing: $isProcessing');
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Previsualización',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Imagen de fondo
          Positioned.fill(
            child: isProcessing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                        const SizedBox(height: 24),
                        const Icon(
                          Icons.auto_fix_high,
                          color: Colors.white70,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          statusMessage.isNotEmpty ? statusMessage : 'Procesando imagen...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esto puede tardar unos segundos',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white70,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error al cargar la imagen',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            fit: BoxFit.contain,
                          )
                        : const Center(
                            child: Text(
                              'No hay imagen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
          ),
          
          // Botones de acción mejorados
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Texto de ayuda
                  const Text(
                    '¿La foto se ve bien?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Botones grandes y claros
                  Row(
                    children: [
                      // Botón Reintentar
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop(false);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 36,
                                    semanticLabel: 'Reintentar foto',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tomar otra',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Botón Usar esta foto
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop(true);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF388E3C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 36,
                                    semanticLabel: 'Aceptar foto',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Usar esta foto',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
