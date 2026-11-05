import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_args.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../auth/bloc/auth_bloc.dart';
import '../common/widgets.dart';

class PaymentConfirmationPage extends StatelessWidget {
  const PaymentConfirmationPage({super.key, required this.args});
  final ConfirmationArgs args;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final t = args.result.ticket;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.check_circle, size: 72, color: AppColors.brand),
                const SizedBox(height: 12),
                Text('COMPRA CONFIRMADA!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.brand)),
                const SizedBox(height: 20),
                AppCard(
                  borderColor: AppColors.brand,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.matchName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Setor ${t.sector.label}  •  ${Fmt.date(t.kickoffAt)} ${Fmt.time(t.kickoffAt)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    if (t.hasSeat) ...[
                      const SizedBox(height: 4),
                      Text('Fileira ${t.seatRow} · Cadeira ${t.seatNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                    const Divider(height: 24),
                    const Text('CÓDIGO DO INGRESSO', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    SelectableText(t.code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4)),
                    const SizedBox(height: 8),
                    Text('Total pago: ${Fmt.money(t.amount)}', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (user != null) TeamLogo(user.team, size: 44),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset('assets/images/champions_card.png', height: 48),
                  ),
                ]),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go('/matches'), child: const Text('VER MAIS PARTIDAS')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.read<AuthBloc>().add(const LogoutRequested()),
                  child: const Text('SAIR', style: TextStyle(color: AppColors.muted, letterSpacing: 2)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
