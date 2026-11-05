import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/match.dart';
import '../../common/widgets.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});
  final Match match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final label = '${match.homeName} contra ${match.awayName}. ${Fmt.date(match.kickoffAt)} às ${Fmt.time(match.kickoffAt)}. '
        'Estádio ${match.stadium.name}. ${match.isFinished ? 'Partida encerrada.' : 'Preço ${Fmt.money(match.price)}.'}'
        '${match.isAway && !match.isFinished ? ' Você é visitante.' : ''}';
    return Semantics(
      button: !match.isFinished,
      label: label,
      hint: match.isFinished ? null : 'Toque duas vezes para ver os ingressos',
      excludeSemantics: true,
      child: Opacity(
      opacity: match.isFinished ? 0.5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: match.isFinished ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              TeamLogo(match.homeTeam, size: 26),
              const SizedBox(width: 8),
              Flexible(child: Text(match.homeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('vs', style: TextStyle(color: AppColors.muted))),
              TeamLogo(match.awayTeam, size: 26),
              const SizedBox(width: 8),
              Flexible(child: Text(match.awayName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(Fmt.date(match.kickoffAt), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              Text(Fmt.time(match.kickoffAt), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              Text(match.stadium.name, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (match.isFinished)
                const Text('ENCERRADA', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.5))
              else if (match.hasDiscount) ...[
                Text(Fmt.money(match.basePrice),
                    style: const TextStyle(color: AppColors.muted, decoration: TextDecoration.lineThrough, fontSize: 13)),
                const SizedBox(width: 8),
                Text(Fmt.money(match.price), style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                  child: Text('-${match.discountPercent}%',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ] else
                Text(Fmt.money(match.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              if (match.isAway && !match.isFinished)
                const Text('VISITANTE', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
            if (!match.isFinished) ...[
              const SizedBox(height: 12),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(999)),
                child: Text('VER INGRESSOS →',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
            ],
          ]),
        ),
      ),
      ),
    );
  }
}
