import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/checkout/checkout_usecases.dart';

enum CheckoutStep { idle, creatingIntent, confirming, success, failure }

sealed class CheckoutEvent {
  const CheckoutEvent();
}

class CheckoutSubmitted extends CheckoutEvent {
  const CheckoutSubmitted({required this.method, required this.code, this.memberCode, this.card});
  final PaymentMethod method;
  final String code; // código de 6 dígitos do autenticador (ou de recuperação)
  final String? memberCode;
  final CardInput? card;
}

class CheckoutState extends Equatable {
  const CheckoutState({
    this.step = CheckoutStep.idle,
    this.intent,
    this.failure,
    this.errorSeq = 0,
    this.result,
  });

  final CheckoutStep step;
  final PaymentIntent? intent;
  final Failure? failure;
  final int errorSeq;
  final PurchaseResult? result;

  bool get busy => step == CheckoutStep.creatingIntent || step == CheckoutStep.confirming;

  String get statusText => switch (step) {
        CheckoutStep.creatingIntent => 'Validando sua compra...',
        CheckoutStep.confirming => 'Conferindo o código e processando o pagamento...',
        _ => '',
      };

  CheckoutState copyWith({
    CheckoutStep? step,
    PaymentIntent? intent,
    bool clearIntent = false,
    Failure? failure,
    int? errorSeq,
    PurchaseResult? result,
  }) =>
      CheckoutState(
        step: step ?? this.step,
        intent: clearIntent ? null : (intent ?? this.intent),
        failure: failure,
        errorSeq: errorSeq ?? this.errorSeq,
        result: result ?? this.result,
      );

  @override
  List<Object?> get props => [step, intent, failure, errorSeq, result];
}

/// Fluxo da compra:
///  1) cria a intenção (backend valida setor/sócio, calcula o valor e devolve o nonce)
///  2) envia o código de 6 dígitos do autenticador (MFA); o backend confere o código e só então cobra
class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc({
    required this.match,
    required this.sector,
    this.seatRow,
    this.seatNumber,
    required CreatePaymentIntentUseCase createIntent,
    required ConfirmPaymentUseCase confirm,
  })  : _createIntent = createIntent,
        _confirm = confirm,
        super(const CheckoutState()) {
    on<CheckoutSubmitted>(_onSubmitted);
  }

  final Match match;
  final Sector sector;
  final int? seatRow;
  final int? seatNumber;
  final CreatePaymentIntentUseCase _createIntent;
  final ConfirmPaymentUseCase _confirm;

  CardInput? _card; // só em memória; nunca vai para o estado/log

  /// Erros após os quais a intenção não serve mais e precisa ser recriada.
  static const _terminalCodes = {'intent_expired', 'too_many_attempts', 'invalid_nonce', 'intent_closed', 'not_found'};

  CheckoutState _fail(Failure f, {bool dropIntent = false}) => CheckoutState(
        step: CheckoutStep.failure,
        intent: dropIntent ? null : state.intent,
        failure: f,
        errorSeq: state.errorSeq + 1,
      );

  Future<void> _onSubmitted(CheckoutSubmitted e, Emitter<CheckoutState> emit) async {
    if (state.busy) return;
    _card = e.card;

    var intent = state.intent;
    final reusable = intent != null && !intent.isExpired && intent.method == e.method;
    if (!reusable) {
      emit(state.copyWith(step: CheckoutStep.creatingIntent, clearIntent: true));
      final r = await _createIntent(
          matchId: match.id, sector: sector, method: e.method, memberCode: e.memberCode, seatRow: seatRow, seatNumber: seatNumber);
      final failure = r.failureOrNull;
      if (failure != null) {
        emit(_fail(failure, dropIntent: true));
        return;
      }
      intent = r.valueOrNull;
      emit(state.copyWith(intent: intent));
    }

    final current = intent;
    if (current == null) return;
    emit(state.copyWith(step: CheckoutStep.confirming));
    final r = await _confirm(intent: current, code: e.code, card: _card);
    r.fold(
      (f) => emit(_fail(f, dropIntent: _terminalCodes.contains(f.code))),
      (result) {
        _card = null; // descarta os dados do cartão
        emit(state.copyWith(step: CheckoutStep.success, result: result));
      },
    );
  }
}
