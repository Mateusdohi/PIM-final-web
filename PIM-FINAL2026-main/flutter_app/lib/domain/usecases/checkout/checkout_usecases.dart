import '../../../core/error/failures.dart';
import '../../entities/payment.dart';
import '../../repositories/repositories.dart';

class CreatePaymentIntentUseCase {
  CreatePaymentIntentUseCase(this._repo);
  final PaymentRepository _repo;

  Future<Result<PaymentIntent>> call({
    required int matchId,
    required Sector sector,
    required PaymentMethod method,
    String? memberCode,
    int? seatRow,
    int? seatNumber,
  }) =>
      _repo.createIntent(
          matchId: matchId, sector: sector, method: method, memberCode: memberCode, seatRow: seatRow, seatNumber: seatNumber);
}

/// Tokeniza o cartão (se houver) e envia o código do autenticador ao backend, que confere e decide a aprovação.
class ConfirmPaymentUseCase {
  ConfirmPaymentUseCase(this._repo, this._tokenizer);
  final PaymentRepository _repo;
  final CardTokenizer _tokenizer;

  Future<Result<PurchaseResult>> call({
    required PaymentIntent intent,
    required String code,
    CardInput? card,
  }) async {
    if (intent.isExpired) {
      return const Err(Failure('intent_expired', 'O tempo para confirmar a compra expirou. Inicie novamente.'));
    }
    String? token;
    if (intent.method.isCard) {
      if (card == null) return const Err(Failure('card_required', 'Informe os dados do cartão.'));
      token = await _tokenizer.tokenize(card);
    }
    if (code.replaceAll(RegExp(r'\s'), '').isEmpty) {
      return const Err(Failure('mfa_code_required', 'Digite o código de 6 dígitos do seu autenticador.'));
    }
    return _repo.confirm(intent: intent, code: code.trim(), cardToken: token);
  }
}

class SubscribePlanUseCase {
  SubscribePlanUseCase(this._repo, this._tokenizer);
  final PaymentRepository _repo;
  final CardTokenizer _tokenizer;

  Future<Result<SubscriptionResult>> call({
    required int planPercent,
    required PaymentMethod method,
    CardInput? card,
  }) async {
    String? token;
    if (method.isCard) {
      if (card == null) return const Err(Failure('card_required', 'Informe os dados do cartão.'));
      token = await _tokenizer.tokenize(card);
    }
    return _repo.subscribe(planPercent: planPercent, method: method, cardToken: token);
  }
}
