import '../entities/seat.dart';
import '../../core/error/failures.dart';
import '../entities/match.dart';
import '../entities/payment.dart';
import '../entities/mfa.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  /// Há sessão guardada no aparelho (refresh token)?
  Future<bool> get hasStoredSession;

  /// Acesso rápido por biometria está ativado neste aparelho?
  Future<bool> get isBiometricEnabled;

  /// Tenta retomar a sessão guardada (renovando o token se preciso).
  Future<Result<User>> restoreSession();

  /// Captcha novo para o login (vale uma tentativa).
  Future<Result<Captcha>> captcha();

  Future<Result<User>> login({
    required String email,
    required String password,
    required String captchaId,
    required String captchaAnswer,
    required bool enableBiometric,
  });
  Future<Result<User>> register(RegisterData data);
  Future<Result<User>> refreshUser();
  Future<Result<User>> updateProfile({required String name, required String team});
  Future<Result<void>> changePassword({required String current, required String next});

  // ---- Autenticador (MFA) ----
  Future<Result<MfaStatus>> mfaStatus();
  Future<Result<MfaSetup>> mfaSetup();
  /// Confirma o primeiro código e ativa. Devolve os códigos de recuperação (aparecem só agora).
  Future<Result<List<String>>> mfaEnable(String code);
  Future<Result<void>> mfaDisable(String password);
  Future<Result<List<String>>> mfaNewRecoveryCodes(String password);

  /// [keepBiometricSession]: mantém o refresh token (protegido pela biometria) para o acesso rápido.
  Future<void> logout({required bool keepBiometricSession});
  Future<void> disableBiometric();
}

abstract class MatchRepository {
  Future<Result<List<Match>>> getMatches({
    MatchScope scope = MatchScope.mine,
    MatchStatusFilter status = MatchStatusFilter.all,
    String? search,
  });
  Future<Result<List<SectorAvailability>>> getSectors(int matchId);
  Future<Result<SeatMap>> getSeats(int matchId, Sector sector);
}

abstract class PaymentRepository {
  Future<Result<PaymentIntent>> createIntent({
    required int matchId,
    required Sector sector,
    required PaymentMethod method,
    String? memberCode,
    int? seatRow,
    int? seatNumber,
  });

  Future<Result<PurchaseResult>> confirm({
    required PaymentIntent intent,
    required String code,
    String? cardToken,
  });

  Future<Result<SubscriptionResult>> subscribe({
    required int planPercent,
    required PaymentMethod method,
    String? cardToken,
  });

  Future<Result<List<Ticket>>> tickets();
}

/// Biometria nativa do aparelho (digital / Face ID do celular), usada só no acesso rápido ao app. Só devolve "ok ou não" localmente.
abstract class BiometricAuthenticator {
  Future<bool> get isAvailable;
  Future<bool> authenticate(String reason);
}

/// Transforma dados de cartão em token. Em produção, use o SDK do gateway de pagamento.
abstract class CardTokenizer {
  Future<String> tokenize(CardInput card);
}

abstract class AdminRepository {
  Future<Result<List<AdminTicket>>> tickets();
}

abstract class ChatRepository {
  Future<Result<ChatReply>> send(String message);
}
