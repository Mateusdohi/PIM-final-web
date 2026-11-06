import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/error/failures.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/repositories.dart';
import '../auth/bloc/auth_bloc.dart';
import '../common/widgets.dart';

/// Área Admin: ingressos vendidos (GET /api/admin/tickets). Quem barra o acesso é o servidor (403);
/// aqui o item de menu só aparece para o Admin.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<Result<List<AdminTicket>>> _future = sl<AdminRepository>().tickets();

  Future<void> _reload() async {
    final f = sl<AdminRepository>().tickets();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select((AuthBloc b) => b.state.user?.isAdmin ?? false);
    return Scaffold(
      appBar: AppBar(title: const Text('ÁREA ADMIN')),
      body: !isAdmin
          ? const Center(child: Text('Acesso negado.'))
          : RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<Result<List<AdminTicket>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  final result = snap.data;
                  if (result == null) return _message('Não foi possível carregar.');
                  return result.fold((f) => _message(f.message), (list) {
                    final total = list.fold<double>(0, (s, t) => s + t.amount);
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        AppCard(
                          borderColor: AppColors.brand,
                          child: Text('${list.length} ingresso(s). Total: ${Fmt.money(total)}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 10),
                        for (final t in list) _Row(t),
                      ],
                    );
                  });
                },
              ),
            ),
    );
  }

  Widget _message(String text) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [const SizedBox(height: 48), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted))],
      );
}

class _Row extends StatelessWidget {
  const _Row(this.t);
  final AdminTicket t;

  @override
  Widget build(BuildContext context) {
    final seat = t.seatRow != null ? 'F${t.seatRow} / N${t.seatNumber}' : '-';
    final when = '${Fmt.date(t.issuedAt)} ${Fmt.time(t.issuedAt)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(t.matchName, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(Fmt.money(t.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 2),
          Text('${t.sector} · Assento $seat · $when', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          Text('Código ${t.code} · Usuário ${t.userId.substring(0, 8)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontFamily: 'monospace')),
        ]),
      ),
    );
  }
}
