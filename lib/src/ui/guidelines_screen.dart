import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guideline_entry.dart';
import '../widgets/lottie_animation_widget.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

final _checkboxProvider = StateProvider.autoDispose<bool>((ref) => false);

class GuidelinesScreen extends ConsumerWidget {
  final GuidelinesConfig config;
  const GuidelinesScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_checkboxProvider) || config.isGuidelinesCheckboxAccepted;
    final showCheckbox = config.showAcceptanceCheckbox && !config.isGuidelinesCheckboxAccepted;
    final guidelines = config.guidelines;

    return Scaffold(
      appBar: AppBar(title: const Text('Lineamientos')),
      body: Column(
        children: [
          // Animación Lottie en la parte superior
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                const ClearFaceLottieWidget(
                  size: 180,
                  repeat: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Lineamientos de captura',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          
          // Lista de lineamientos
          Expanded(
            child: guidelines.isEmpty
                ? const Center(child: Text('No hay lineamientos definidos'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (c, i) {
                      final g = guidelines[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ', style: g.style ?? const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              g.text,
                              style: g.style ?? const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemCount: guidelines.length,
                  ),
          ),
          if (showCheckbox)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CheckboxListTile(
                value: checked,
                onChanged: (v) => ref.read(_checkboxProvider.notifier).state = v ?? false,
                title: const Text('He leído y acepto los lineamientos'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // Solo deshabilitar si se muestra el checkbox Y no está marcado
                    // Si no se muestra checkbox, siempre habilitar
                    onPressed: (showCheckbox && !checked)
                        ? null
                        : () async {
                            if (!context.mounted) return;
                            final file = await context.push<File?>(
                              '/datamex-camera-overlay',
                              extra: {
                                'useFaceDetection': config.useFaceDetection,
                                'startsWithSelfie': config.startsWithSelfie,
                                'showOverlay': config.showOverlay,
                                'showFaceGuides': config.showFaceGuides,
                              },
                            );
                            if (!context.mounted) return;
                            // Regresar a quien abrió '/datamex-guidelines' con el archivo resultante
                            context.pop(file);
                          },
                    child: const Text('Acepto los lineamientos'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
