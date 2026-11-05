import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/error/failures.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/repositories.dart';
import '../common/widgets.dart';

/// "Meus ingressos": lista os ingressos já comprados pelo usuário (GET /api/tickets).
class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late Future<Result<List<Ticket>>> _future = sl<PaymentRepository>().tickets();

  Future<void> _reload() async {
    final f = sl<PaymentRepository>().tickets();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MEUS INGRESSOS')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<Result<List<Ticket>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snap.data;
            if (result == null) return _message(context, 'Não foi possível carregar seus ingressos.');
            return result.fold(
              (failure) => _message(context, failure.message, retry: true),
              (tickets) {
                if (tickets.isEmpty) {
                  return _message(context, 'Você ainda não comprou nenhum ingresso.', icon: Icons.confirmation_number_outlined);
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _TicketCard(ticket: tickets[i]),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text, {bool retry = false, IconData icon = Icons.error_outline}) {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: [
      const SizedBox(height: 48),
      Icon(icon, size: 48, color: AppColors.muted),
      const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      if (retry) ...[
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _reload, child: const Text('TENTAR NOVAMENTE')),
      ],
    ]);
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final when = '${Fmt.date(ticket.kickoffAt)} às ${Fmt.time(ticket.kickoffAt)}';
    return Semantics(
      container: true,
      label: 'Ingresso para ${ticket.matchName}. $when. Setor ${ticket.sector.apiValue}.${ticket.hasSeat ? ' Fileira ${ticket.seatRow}, cadeira ${ticket.seatNumber}.' : ''} '
          'Código ${ticket.code.split('').join(' ')}. Valor ${Fmt.money(ticket.amount)}.',
      child: ExcludeSemantics(
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Text(ticket.matchName.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(when, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(999)),
                    child: Text('SETOR ${ticket.sector.label}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                  const Spacer(),
                  Text(Fmt.money(ticket.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                if (ticket.hasSeat) ...[
                  Text('Fileira ${ticket.seatRow} · Cadeira ${ticket.seatNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                ],
                const Text('CÓDIGO DO INGRESSO', style: TextStyle(fontSize: 11, color: AppColors.muted, letterSpacing: 1)),
                const SizedBox(height: 2),
                SelectableText(ticket.code,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 2)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
