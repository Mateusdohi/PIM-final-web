import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cart/cart_service.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/checkout/checkout_usecases.dart';
import '../auth/bloc/auth_bloc.dart';
import '../checkout/checkout_page.dart' show PixPanel;
import '../checkout/widgets/card_form.dart';
import '../common/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Carrinho: vários assentos, um código do autenticador (MFA), e cada assento vira uma compra na API.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _cart = sl<CartService>();
  final _card = CardFormController();
  final _memberCode = TextEditingController();
  final _memberKey = GlobalKey<FormState>();
  final _mfaCode = TextEditingController();
  PaymentMethod _method = PaymentMethod.credit;
  bool _busy = false;
  String _status = '';

  // Erros depois dos quais não adianta tentar os outros itens (igual ao web).
  static const _keepGoing = {'seat_taken', 'queue_required'};

  @override
  void dispose() {
    _card.dispose();
    _memberCode.dispose();
    _mfaCode.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isMember) async {
    if (_busy || _cart.isEmpty) return;
    final okMember = !isMember || (_memberKey.currentState?.validate() ?? false);
    final okCard = !_method.isCard || _card.validate();
    if (!okMember || !okCard) return;
    FocusScope.of(context).unfocus();

    final user = context.read<AuthBloc>().state.user;
    if (!(user?.mfaEnabled ?? false)) {
      showAppSnack(context, 'Ative o autenticador (MFA) no perfil para comprar.', error: true);
      context.push('/mfa');
      return;
    }
    final code = _mfaCode.text.trim();
    if (code.isEmpty) {
      showAppSnack(context, 'Digite o código de 6 dígitos do seu autenticador.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Conferindo o código...';
    });

    // Uma compra por assento; o mesmo código vale para todos (o servidor aceita repeti-lo dentro dos mesmos 30 s).
    final card = _method.isCard ? _card.read() : null;
    final memberCode = isMember ? _memberCode.text.trim().toUpperCase() : null;
    var bought = 0;
    String? fatal;
    for (final item in List<CartItem>.of(_cart.items)) {
      if (!mounted) return;
      item.error = null;
      setState(() => _status = 'Processando ${bought + 1} de ${_cart.count}...');

      final intent = await sl<CreatePaymentIntentUseCase>()(
        matchId: item.match.id,
        sector: item.sector,
        method: _method,
        memberCode: memberCode,
        seatRow: item.row,
        seatNumber: item.number,
      );
      var failure = intent.failureOrNull;
      if (failure == null) {
        final done = await sl<ConfirmPaymentUseCase>()(intent: intent.valueOrNull!, code: code, card: card);
        failure = done.failureOrNull;
      }
      if (failure == null) {
        bought++;
        _cart.remove(item);
        continue;
      }
      item.error = failure.message;
      _cart.touch();
      if (failure.code == 'invalid_mfa_code') _mfaCode.clear();
      if (!_keepGoing.contains(failure.code)) {
        fatal = failure.message;
        break;
      }
    }
    if (!mounted) return;

    _stop(null);
    if (_cart.isEmpty && bought > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$bought ingresso(s) comprado(s).')));
      context.go('/matches');
      context.push('/tickets');
      return;
    }
    final text = bought > 0
        ? '$bought ingresso(s) comprado(s). ${_cart.count} ficou no carrinho: veja o motivo em cada item.'
        : (fatal ?? 'Não foi possível finalizar a compra.');
    showAppSnack(context, text, error: bought == 0);
  }

  void _stop(String? message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '';
    });
    if (message != null) showAppSnack(context, message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    final isMember = user?.isMember ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('CARRINHO')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _cart,
          builder: (context, _) {
            if (_cart.isEmpty) return _empty(context);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final item in _cart.items) _ItemTile(item: item, onRemove: _busy ? null : () => _cart.remove(item)),
                const SizedBox(height: 4),
                Text('TOTAL: ${Fmt.money(_cart.total)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w900, fontSize: 18)),
                if (isMember) ...[
                  const SizedBox(height: 16),
                  const SectionLabel('CÓDIGO DE SÓCIO'),
                  Form(
                    key: _memberKey,
                    child: TextFormField(
                      controller: _memberCode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'SEU CÓDIGO DE SÓCIO', helperText: 'Necessário para aplicar o desconto'),
                      validator: (v) => Validators.required(v, 'Informe seu código de sócio'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const SectionLabel('FORMA DE PAGAMENTO'),
                SizedBox(
                  width: double.infinity,
                  child: PaymentMethodSelector(value: _method, onChanged: _busy ? (_) {} : (m) => setState(() => _method = m)),
                ),
                const SizedBox(height: 16),
                if (_method.isCard) CardForm(controller: _card) else PixPanel(amount: _cart.total),
                const SizedBox(height: 20),
                const SectionLabel('CÓDIGO DO AUTENTICADOR'),
                TextField(
                  controller: _mfaCode,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 14,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    labelText: 'CÓDIGO DE 6 DÍGITOS',
                    helperText: 'Um único código confirma todos os ingressos do carrinho',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                BusyButton(label: 'FINALIZAR COMPRA', icon: Icons.verified_user, busy: _busy, onPressed: () => _submit(isMember)),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('Seu carrinho está vazio.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => context.go('/matches'), child: const Text('ESCOLHER PARTIDA')),
          ]),
        ),
      );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onRemove});
  final CartItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final m = item.match;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: item.error != null ? AppColors.danger : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${item.sector.label} · Fileira ${item.row}, cadeira ${item.number}',
                    style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${Fmt.date(m.kickoffAt)} às ${Fmt.time(m.kickoffAt)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            ),
            Text(Fmt.money(m.price), style: const TextStyle(fontWeight: FontWeight.w900)),
            IconButton(tooltip: 'Remover do carrinho', onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
          ]),
          if (item.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
