import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/route_args.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/team_theme.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/matches/match_usecases.dart';
import '../auth/bloc/auth_bloc.dart';
import '../accessibility/accessibility_sheet.dart';
import '../cart/cart_button.dart';
import '../common/widgets.dart';
import '../../core/cart/cart_service.dart';
import 'bloc/matches_cubit.dart';
import 'widgets/match_card.dart';

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => MatchesCubit(sl<GetMatchesUseCase>())..load(),
        child: const _MatchesView(),
      );
}

class _MatchesView extends StatefulWidget {
  const _MatchesView();

  @override
  State<_MatchesView> createState() => _MatchesViewState();
}

class _MatchesViewState extends State<_MatchesView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => context.read<MatchesCubit>().load(search: v));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    final team = TeamTheme.of(user?.team);
    final cubit = context.read<MatchesCubit>();
    sl<CartService>().bindUser(user?.id); // carrinho não passa de um usuário para outro

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Image.asset('assets/images/champions_card.png', height: 34),
          const SizedBox(width: 10),
          const Text('CHAMPIONS\nCARD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, height: 1.15, color: Colors.white)),
        ]),
        actions: [
          const CartButton(),
          PopupMenuButton<String>(
            tooltip: 'Abrir menu',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              final auth = context.read<AuthBloc>();
              switch (v) {
                case 'tickets':
                  context.push('/tickets');
                case 'profile':
                  context.push('/profile');
                case 'about':
                  context.push('/about');
                case 'admin':
                  context.push('/admin');
                case 'access':
                  showAccessibilitySheet(context);
                case 'plans':
                  context.push('/plans', extra: const PlansArgs());
                case 'mfa':
                  context.push('/mfa');
                case 'logout':
                  auth.add(const LogoutRequested());
                case 'forget':
                  auth.add(const LogoutRequested(forgetDevice: true));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'tickets', child: Text('Meus ingressos')),
              const PopupMenuItem(value: 'profile', child: Text('Perfil')),
              const PopupMenuItem(value: 'about', child: Text('Quem somos')),
              if (user != null && user.isAdmin) const PopupMenuItem(value: 'admin', child: Text('Área Admin')),
              const PopupMenuItem(value: 'access', child: Text('Acessibilidade')),
              if (user != null && !user.isMember) const PopupMenuItem(value: 'plans', child: Text('Quero ser sócio')),
              PopupMenuItem(value: 'mfa', child: Text(user?.mfaEnabled == true ? 'Autenticador (MFA)' : 'Ativar autenticador (MFA)')),
              const PopupMenuItem(value: 'logout', child: Text('Sair')),
              const PopupMenuItem(value: 'forget', child: Text('Sair e esquecer este aparelho')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Assistente de dúvidas',
        onPressed: () => context.push('/chat'),
        child: const Icon(Icons.chat_bubble_outline),
      ),
      body: RefreshIndicator(
        onRefresh: () => cubit.load(),
        child: BlocBuilder<MatchesCubit, MatchesState>(
          builder: (context, state) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Saudação (igual ao topo da tela de partidas do web)
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    (user?.name.isNotEmpty ?? false) ? user!.name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Olá, ${(user?.name ?? '').split(' ').first}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const Text('Aqui estão as partidas disponíveis para você.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              AppCard(
                borderColor: AppColors.brand,
                child: Text(team.news, style: const TextStyle(height: 1.4)),
              ),
              if (user != null && !user.mfaEnabled) ...[
                const SizedBox(height: 12),
                AppCard(
                  borderColor: AppColors.warning,
                  child: Row(children: [
                    const Icon(Icons.shield_outlined, color: AppColors.warning),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Ative o autenticador (MFA) para poder comprar ingressos.', style: TextStyle(fontSize: 13))),
                    TextButton(onPressed: () => context.push('/mfa'), child: const Text('ATIVAR')),
                  ]),
                ),
              ],
              if (user != null && user.isMember) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Row(children: [
                    const Icon(Icons.workspace_premium, color: AppColors.brand),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${user.planName} • ${user.planPercent}% de desconto', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              const SectionLabel('Partidas Disponíveis'),
              TextField(
                onChanged: _onSearch,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar time ou estádio'),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [
                ChoiceChip(
                  label: const Text('MEU TIME'),
                  selected: state.scope == MatchScope.mine,
                  onSelected: (_) => cubit.load(scope: MatchScope.mine),
                ),
                ChoiceChip(
                  label: const Text('TODOS OS JOGOS'),
                  selected: state.scope == MatchScope.all,
                  onSelected: (_) => cubit.load(scope: MatchScope.all),
                ),
                const SizedBox(width: 8),
                for (final f in MatchStatusFilter.values)
                  FilterChip(
                    label: Text(switch (f) {
                      MatchStatusFilter.all => 'TODAS',
                      MatchStatusFilter.scheduled => 'PRÓXIMAS',
                      MatchStatusFilter.finished => 'ENCERRADAS',
                    }),
                    selected: state.filter == f,
                    onSelected: (_) => cubit.load(filter: f),
                  ),
              ]),
              const SizedBox(height: 16),
              ..._content(context, state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, MatchesState state) {
    switch (state.status) {
      case LoadStatus.loading:
        return const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))];
      case LoadStatus.failure:
        return [
          AppCard(
            borderColor: AppColors.danger,
            child: Column(children: [
              Text(state.failure?.message ?? 'Erro ao carregar partidas.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => context.read<MatchesCubit>().load(), child: const Text('TENTAR NOVAMENTE')),
            ]),
          ),
        ];
      case LoadStatus.success:
        if (state.matches.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('NENHUMA PARTIDA DISPONÍVEL.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, letterSpacing: 1.5)),
            ),
          ];
        }
        return [
          for (final m in state.matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MatchCard(match: m, onTap: () => context.push('/map', extra: m)),
            ),
        ];
    }
  }
}
