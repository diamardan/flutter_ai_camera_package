import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Sistema de logging interno para depuración sin USB debugging
/// Guarda logs en archivo y permite visualización en pantalla
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final List<String> _logs = [];
  final int _maxLogs = 500;
  StreamController<String>? _logStreamController;
  File? _logFile;
  bool _initialized = false;

  /// Inicializar el logger (llamar al inicio de la app)
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/debug_logs.txt');
      
      // Crear archivo si no existe
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      
      _logStreamController = StreamController<String>.broadcast();
      _initialized = true;
      
      await log('📱 DebugLogger iniciado - ${DateTime.now()}');
      await log('📱 Plataforma: ${Platform.operatingSystem}');
      await log('📱 Versión: ${Platform.operatingSystemVersion}');
    } catch (e) {
      debugPrint('Error inicializando DebugLogger: $e');
    }
  }

  /// Registrar un log
  Future<void> log(String message, {String? tag}) async {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final logMessage = '$timestamp $tagPrefix$message';
    
    // Añadir a memoria
    _logs.add(logMessage);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    // Emitir al stream para UI
    _logStreamController?.add(logMessage);
    
    // Imprimir en consola debug
    debugPrint(logMessage);
    
    // Escribir a archivo
    try {
      await _logFile?.writeAsString(
        '$logMessage\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('Error escribiendo log: $e');
    }
  }

  /// Obtener todos los logs en memoria
  List<String> getLogs() => List.unmodifiable(_logs);

  /// Stream de logs para UI en tiempo real
  Stream<String>? get logStream => _logStreamController?.stream;

  /// Limpiar logs
  Future<void> clear() async {
    _logs.clear();
    try {
      await _logFile?.writeAsString('', flush: true);
      await log('🗑️ Logs limpiados');
    } catch (e) {
      debugPrint('Error limpiando logs: $e');
    }
  }

  /// Obtener ruta del archivo de logs
  String? getLogFilePath() => _logFile?.path;

  /// Exportar logs como string
  String exportLogs() {
    return _logs.join('\n');
  }

  /// Cerrar el logger
  Future<void> dispose() async {
    await _logStreamController?.close();
    _logStreamController = null;
    _initialized = false;
  }
}

/// Helper para log rápido
Future<void> dlog(String message, {String? tag}) async {
  await DebugLogger().log(message, tag: tag);
}
