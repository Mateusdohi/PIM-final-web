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
import '../auth/face_capture_page.dart';
import '../checkout/checkout_page.dart' show PixPanel;
import '../checkout/widgets/card_form.dart';
import '../common/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Carrinho: vários assentos, uma biometria e uma selfie, e cada assento vira uma compra na API.
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
  PaymentMethod _method = PaymentMethod.credit;
  bool _busy = false;
  String _status = '';

  // Erros depois dos quais não adianta tentar os outros itens (igual ao web).
  static const _keepGoing = {'seat_taken', 'queue_required'};

  @override
  void dispose() {
    _card.dispose();
    _memberCode.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isMember) async {
    if (_busy || _cart.isEmpty) return;
    final okMember = !isMember || (_memberKey.currentState?.validate() ?? false);
    final okCard = !_method.isCard || _card.validate();
    if (!okMember || !okCard) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _status = 'Confirme com sua biometria';
    });

    // 1) biometria e 2) selfie: uma vez só para todo o carrinho
    final bio = await sl<RequireBiometricUseCase>()();
    final bioFailure = bio.failureOrNull;
    if (bioFailure != null) return _stop(bioFailure.message);
    if (!mounted) return;

    setState(() => _status = 'Tire uma selfie para confirmar');
    final shots = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
      builder: (_) => const FaceCapturePage(
        title: 'CONFIRME SUA IDENTIDADE',
        hint: 'Tire uma selfie agora para confirmar a compra',
      ),
    ));
    if (shots == null || shots.isEmpty || !mounted) return _stop(null);

    // 3) uma compra por assento
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
        final done = await sl<ConfirmPaymentUseCase>()(intent: intent.valueOrNull!, selfiePath: shots.first, card: card);
        failure = done.failureOrNull;
      }
      if (failure == null) {
        bought++;
        _cart.remove(item);
        continue;
      }
      item.error = failure.message;
      _cart.touch();
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
                const Row(children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Vamos confirmar com a biometria do aparelho e uma selfie, uma vez para todo o carrinho.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),
                BusyButton(label: 'FINALIZAR COMPRA', icon: Icons.fingerprint, busy: _busy, onPressed: () => _submit(isMember)),
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
