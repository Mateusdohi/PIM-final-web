import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/match.dart';
import '../../presentation/auth/bloc/auth_bloc.dart';
import '../../presentation/about/about_page.dart';
import '../../presentation/admin/admin_page.dart';
import '../../presentation/auth/mfa_page.dart';
import '../../presentation/auth/login_page.dart';
import '../../presentation/auth/register_page.dart';
import '../../presentation/cart/cart_page.dart';
import '../../presentation/chat/chat_page.dart';
import '../../presentation/checkout/checkout_page.dart';
import '../../presentation/checkout/payment_confirmation_page.dart';
import '../../presentation/checkout/plans_page.dart';
import '../../presentation/home/matches_page.dart';
import '../../presentation/profile/profile_page.dart';
import '../../presentation/seats/seats_page.dart';
import '../../presentation/tickets/tickets_page.dart';
import '../../presentation/home/team_splash_page.dart';
import '../../presentation/map/map_page.dart';
import 'route_args.dart';

/// Faz o GoRouter reavaliar o redirect quando o estado de autenticação muda.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildRouter(AuthBloc auth) {
  // Rotas acessíveis sem login. /register NÃO redireciona quando já autenticado:
  // a própria tela leva o usuário aos planos/ao app logo após criar a conta.
  const publicRoutes = {'/login', '/register'};

  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: GoRouterRefreshStream(auth.stream),
    redirect: (context, state) {
      final s = auth.state;
      final loc = state.matchedLocation;

      if (s.status == AuthStatus.unknown) return loc == '/boot' ? null : '/boot';

      final loggedIn = s.status == AuthStatus.authenticated;
      if (!loggedIn) return publicRoutes.contains(loc) ? null : '/login';
      if (loc == '/boot' || loc == '/login') return '/splash';
      return null;
    },
    routes: [
      GoRoute(path: '/boot', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/mfa', builder: (_, __) => const MfaPage()),
      GoRoute(
        path: '/plans',
        builder: (_, state) => PlansPage(args: state.extra is PlansArgs ? state.extra! as PlansArgs : const PlansArgs()),
      ),
      GoRoute(path: '/splash', builder: (_, __) => const TeamSplashPage()),
      GoRoute(path: '/matches', builder: (_, __) => const MatchesPage()),
      GoRoute(path: '/tickets', builder: (_, __) => const TicketsPage()),
      GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPage()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
      GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(
        path: '/map',
        redirect: (_, state) => state.extra is Match ? null : '/matches',
        builder: (_, state) => MapPage(match: state.extra! as Match),
      ),
      GoRoute(
        path: '/seats',
        redirect: (_, state) => state.extra is SeatsArgs ? null : '/matches',
        builder: (_, state) => SeatsPage(args: state.extra! as SeatsArgs),
      ),
      GoRoute(
        path: '/checkout',
        redirect: (_, state) => state.extra is CheckoutArgs ? null : '/matches',
        builder: (_, state) => CheckoutPage(args: state.extra! as CheckoutArgs),
      ),
      GoRoute(
        path: '/confirmation',
        redirect: (_, state) => state.extra is ConfirmationArgs ? null : '/matches',
        builder: (_, state) => PaymentConfirmationPage(args: state.extra! as ConfirmationArgs),
      ),
    ],
  );
}
