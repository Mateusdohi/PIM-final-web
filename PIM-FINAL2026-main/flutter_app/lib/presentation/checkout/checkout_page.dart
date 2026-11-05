import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/di/injection.dart';
import '../../core/router/route_args.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/checkout/checkout_usecases.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/face_capture_page.dart';
import '../common/widgets.dart';
import 'bloc/checkout_bloc.dart';
import 'widgets/card_form.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.args});
  final CheckoutArgs args;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CheckoutBloc(
          match: args.match,
          sector: args.sector,
          seatRow: args.seatRow,
          seatNumber: args.seatNumber,
          createIntent: sl<CreatePaymentIntentUseCase>(),
          requireBiometric: sl<RequireBiometricUseCase>(),
          confirm: sl<ConfirmPaymentUseCase>(),
        ),
        child: _CheckoutView(args: args),
      );
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView({required this.args});
  final CheckoutArgs args;

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final _card = CardFormController();
  final _memberCode = TextEditingController();
  final _memberKey = GlobalKey<FormState>();
  PaymentMethod _method = PaymentMethod.credit;

  @override
  void dispose() {
    _card.dispose();
    _memberCode.dispose();
    super.dispose();
  }

  void _submit(bool isMember) {
    final okMember = !isMember || (_memberKey.currentState?.validate() ?? false);
    final okCard = !_method.isCard || _card.validate();
    if (!okMember || !okCard) return;
    FocusScope.of(context).unfocus();
    context.read<CheckoutBloc>().add(CheckoutSubmitted(
          method: _method,
          memberCode: isMember ? _memberCode.text.trim().toUpperCase() : null,
          card: _method.isCard ? _card.read() : null,
        ));
  }

  Future<void> _openCamera() async {
    final bloc = context.read<CheckoutBloc>();
    // Uma única selfie confirma a compra (a prova de vida com duas fotos está desativada).
    final shots = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
      builder: (_) => const FaceCapturePage(
        title: 'CONFIRME SUA IDENTIDADE',
        hint: 'Tire uma selfie agora para confirmar a compra',
      ),
    ));
    if (shots == null || shots.isEmpty || !mounted) {
      bloc.add(const SelfieCancelled());
      return;
    }
    bloc.add(SelfieCaptured(shots.first));
  }

  Future<void> _onFailure(BuildContext context, CheckoutState s) async {
    final f = s.failure!;
    if (f.isFaceNotEnrolled) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cadastre seu rosto'),
          content: const Text('Para confirmar compras precisamos do seu cadastro facial.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('AGORA NÃO')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CADASTRAR')),
          ],
        ),
      );
      if (go == true && context.mounted) context.push('/face-enroll', extra: const FaceEnrollArgs());
      return;
    }
    showAppSnack(context, f.message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.args.match;
    final sector = widget.args.sector;
    final user = context.select((AuthBloc b) => b.state.user);
    final isMember = user?.isMember ?? false;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('PAGAMENTO')),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<CheckoutBloc, CheckoutState>(
              listenWhen: (p, c) => p.step != c.step && c.step == CheckoutStep.awaitingSelfie,
              listener: (_, __) => _openCamera(),
            ),
            BlocListener<CheckoutBloc, CheckoutState>(
              listenWhen: (p, c) => p.errorSeq != c.errorSeq && c.failure != null,
              listener: _onFailure,
            ),
            BlocListener<CheckoutBloc, CheckoutState>(
              listenWhen: (p, c) => p.step != c.step && c.step == CheckoutStep.success,
              listener: (context, s) => context.go('/confirmation', extra: ConfirmationArgs(s.result!)),
            ),
          ],
          child: BlocBuilder<CheckoutBloc, CheckoutState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppCard(
                  borderColor: primary,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${match.title} (${sector.label})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    if (widget.args.seatRow != null && widget.args.seatNumber != null) ...[
                      const SizedBox(height: 4),
                      Text('Fileira ${widget.args.seatRow} · Cadeira ${widget.args.seatNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand)),
                    ],
                    const SizedBox(height: 4),
                    Text('📅 ${Fmt.date(match.kickoffAt)}   ⏰ ${Fmt.time(match.kickoffAt)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (match.hasDiscount) ...[
                        Text(Fmt.money(match.basePrice),
                            style: const TextStyle(color: AppColors.muted, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                      ],
                      Text('TOTAL: ${Fmt.money(state.intent?.amount ?? match.price)}',
                          style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 18)),
                    ]),
                  ]),
                ),
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
                  child: PaymentMethodSelector(value: _method, onChanged: state.busy ? (_) {} : (m) => setState(() => _method = m)),
                ),
                const SizedBox(height: 16),
                if (_method.isCard)
                  CardForm(controller: _card)
                else
                  _PixPanel(amount: state.intent?.amount ?? match.price),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Para sua segurança, vamos confirmar a compra com a biometria do aparelho e uma selfie.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),
                BusyButton(
                  label: 'CONFIRMAR COMPRA',
                  icon: Icons.fingerprint,
                  busy: state.busy,
                  onPressed: () => _submit(isMember),
                ),
                if (state.statusText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(state.statusText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pagamento por Pix: o QR Code e a chave aparecem ANTES de confirmar a compra (igual ao web).
/// Ambiente de teste: o pagamento é simulado, não há cobrança real.
class _PixPanel extends StatelessWidget {
  const _PixPanel({required this.amount});
  final double amount;

  static const _chave = 'ingressos@ticketfut.com.br';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('PAGUE COM PIX', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Valor: ${Fmt.money(amount)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 14),
        Semantics(
          label: 'QR Code do Pix. Chave Pix $_chave',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSoft)),
            child: QrImageView(data: _chave, size: 170, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        const Text('CHAVE PIX', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 2),
        const SelectableText(_chave, style: TextStyle(fontWeight: FontWeight.w800)),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: _chave));
            showAppSnack(context, 'Chave Pix copiada');
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('COPIAR CHAVE'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pague pelo QR Code ou pela chave e depois toque em "Confirmar compra". Ambiente de teste: o pagamento é simulado.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ]),
    );
  }
}
