import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticketfut/core/error/failures.dart';
import 'package:ticketfut/domain/entities/payment.dart';
import 'package:ticketfut/domain/repositories/repositories.dart';
import 'package:ticketfut/domain/usecases/checkout/checkout_usecases.dart';

class _MockRepo extends Mock implements PaymentRepository {}

class _MockTokenizer extends Mock implements CardTokenizer {}

void main() {
  PaymentIntent intentFor(PaymentMethod m, {Duration validFor = const Duration(minutes: 5)}) => PaymentIntent(
        id: 'i1', nonce: 'n', amount: 100, originalAmount: 100, discountPercent: 0,
        expiresAt: DateTime.now().toUtc().add(validFor), method: m,
      );

  group('ConfirmPaymentUseCase (código do autenticador)', () {
    test('exige cartão quando o método é cartão', () async {
      final uc = ConfirmPaymentUseCase(_MockRepo(), _MockTokenizer());
      final r = await uc(intent: intentFor(PaymentMethod.credit), code: '123456');
      expect(r.failureOrNull?.code, 'card_required');
    });

    test('recusa intenção expirada sem chamar o backend', () async {
      final repo = _MockRepo();
      final r = await ConfirmPaymentUseCase(repo, _MockTokenizer())(
          intent: intentFor(PaymentMethod.pix, validFor: const Duration(seconds: -1)), code: '123456');
      expect(r.failureOrNull?.code, 'intent_expired');
      verifyZeroInteractions(repo);
    });

    test('exige o código do autenticador e não chama o backend sem ele', () async {
      final repo = _MockRepo();
      final r = await ConfirmPaymentUseCase(repo, _MockTokenizer())(intent: intentFor(PaymentMethod.pix), code: '  ');
      expect(r.failureOrNull?.code, 'mfa_code_required');
      verifyZeroInteractions(repo);
    });

    test('envia o código (sem espaços nas pontas) ao repositório', () async {
      final repo = _MockRepo();
      final intent = intentFor(PaymentMethod.pix);
      when(() => repo.confirm(intent: intent, code: '123456', cardToken: null))
          .thenAnswer((_) async => const Err(Failure('invalid_mfa_code', 'x')));
      final r = await ConfirmPaymentUseCase(repo, _MockTokenizer())(intent: intent, code: ' 123456 ');
      expect(r.failureOrNull?.code, 'invalid_mfa_code');
      verify(() => repo.confirm(intent: intent, code: '123456', cardToken: null)).called(1);
    });
  });

  group('Failure', () {
    test('reconhece o bloqueio por falta de MFA', () {
      expect(const Failure('mfa_required', 'x').isMfaRequired, isTrue);
      expect(const Failure('other', 'x').isMfaRequired, isFalse);
    });
  });
}
