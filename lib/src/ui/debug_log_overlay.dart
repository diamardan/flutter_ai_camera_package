import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/debug_logger.dart';

/// Pantalla flotante de logs para depuración en dispositivos sin USB
class DebugLogOverlay extends StatefulWidget {
  const DebugLogOverlay({super.key});

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  final _logger = DebugLogger();
  final _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black,
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Debug Logs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Auto-scroll toggle
                  IconButton(
                    icon: Icon(
                      _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                      color: _autoScroll ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _autoScroll = !_autoScroll),
                    tooltip: 'Auto-scroll',
                  ),
                  // Compartir logs
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue, size: 20),
                    onPressed: _shareLogs,
                    tooltip: 'Compartir logs',
                  ),
                  // Copiar logs
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.orange, size: 20),
                    onPressed: _copyLogs,
                    tooltip: 'Copiar al portapapeles',
                  ),
                  // Limpiar logs
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: _clearLogs,
                    tooltip: 'Limpiar logs',
                  ),
                  // Cerrar
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            
            // Filtro
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Filtrar logs...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white, size: 16),
                          onPressed: () => setState(() => _filter = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) => setState(() => _filter = value.toLowerCase()),
              ),
            ),
            
            // Logs
            Expanded(
              child: Container(
                color: Colors.black,
                child: StreamBuilder<String>(
                  stream: _logger.logStream,
                  builder: (context, snapshot) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    
                    final logs = _logger.getLogs();
                    final filteredLogs = _filter.isEmpty
                        ? logs
                        : logs.where((log) => log.toLowerCase().contains(_filter)).toList();
                    
                    if (filteredLogs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay logs',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _LogItem(log: log);
                      },
                    );
                  },
                ),
              ),
            ),
            
            // Footer con info
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[900],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total: ${_logger.getLogs().length} logs',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  if (_logger.getLogFilePath() != null)
                    Text(
                      'Archivo: ${_logger.getLogFilePath()}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareLogs() async {
    final logs = _logger.exportLogs();
    final filePath = _logger.getLogFilePath();
    
    await Clipboard.setData(ClipboardData(text: logs));
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logs exportados'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Logs copiados al portapapeles.'),
              const SizedBox(height: 12),
              if (filePath != null) ...[
                const Text('Archivo guardado en:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  filePath,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _copyLogs() async {
    final logs = _logger.exportLogs();
    await Clipboard.setData(ClipboardData(text: logs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copiados al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearLogs() async {
    await _logger.clear();
    if (mounted) {
      setState(() {});
    }
  }
}

class _LogItem extends StatelessWidget {
  final String log;

  const _LogItem({required this.log});

  Color _getLogColor() {
    if (log.contains('❌') || log.contains('ERROR') || log.contains('FAILED')) {
      return Colors.red;
    }
    if (log.contains('⚠️') || log.contains('WARNING') || log.contains('WARN')) {
      return Colors.orange;
    }
    if (log.contains('✅') || log.contains('SUCCESS') || log.contains('COMPLETED')) {
      return Colors.green;
    }
    if (log.contains('🎨') || log.contains('PROCESSING')) {
      return Colors.blue;
    }
    if (log.contains('[FaceDetection]')) {
      return Colors.purple;
    }
    if (log.contains('[Camera]') || log.contains('[Capture]')) {
      return Colors.cyan;
    }
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SelectableText(
        log,
        style: TextStyle(
          color: _getLogColor(),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
