import 'package:flutter/material.dart';

import '../../core/accessibility/accessibility_settings.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';

/// Painel de acessibilidade: tamanho do texto e alto contraste.
Future<void> showAccessibilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => const _AccessibilitySheet(),
  );
}

/// Botão de acessibilidade para colocar em barras de título.
class AccessibilityButton extends StatelessWidget {
  const AccessibilityButton({super.key, this.color = Colors.white});
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Acessibilidade',
        icon: Icon(Icons.accessibility_new, color: color),
        onPressed: () => showAccessibilitySheet(context),
      );
}

class _AccessibilitySheet extends StatelessWidget {
  const _AccessibilitySheet();

  @override
  Widget build(BuildContext context) {
    final settings = sl<AccessibilitySettings>();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Acessibilidade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Ajuste o aplicativo para ler e usar com mais conforto.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            const Text('Tamanho do texto', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Semantics(
              label: 'Tamanho do texto',
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.brand,
                ),
                segments: const [
                  ButtonSegment(value: 0, label: Text('Normal')),
                  ButtonSegment(value: 1, label: Text('Grande')),
                  ButtonSegment(value: 2, label: Text('Maior')),
                ],
                selected: {settings.scaleIndex},
                onSelectionChanged: (s) => settings.setScaleIndex(s.first),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alto contraste', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Textos e bordas mais escuros'),
              value: settings.highContrast,
              onChanged: settings.setHighContrast,
            ),
            const SizedBox(height: 8),
            const Text(
              'O aplicativo também funciona com leitores de tela (TalkBack no Android e VoiceOver no iPhone).',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ]),
        ),
      ),
    );
  }
}
