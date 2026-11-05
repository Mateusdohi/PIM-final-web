import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/team.dart';

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFF7A1C14) : AppColors.navy,
    duration: const Duration(seconds: 4),
  ));
}

class TeamLogo extends StatelessWidget {
  const TeamLogo(this.slug, {super.key, this.size = 24});
  final String slug;
  final double size;

  @override
  Widget build(BuildContext context) {
    final team = TeamInfo.of(slug);
    if (team == null) return SizedBox(width: size, height: size);
    return Image.asset(
      team.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.shield_outlined, size: size),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? AppColors.borderSoft),
        ),
        child: child,
      );
}

/// Botão principal com estado de carregamento (desabilita enquanto [busy]).
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ],
          );
    return FilledButton(onPressed: busy ? null : onPressed, child: child);
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Container(width: 28, height: 3, decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(2))),
        ]),
      );
}
