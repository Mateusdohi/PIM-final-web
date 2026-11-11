import 'package:dio/dio.dart';

import '../../../domain/entities/payment.dart';
import '../../models/models.dart';
import '../../models/seat_model.dart';
import '../../../domain/entities/seat.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/mfa.dart';

/// Falam com o backend C#. Lançam DioException; os repositórios convertem em Result.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);
  final Dio _dio;

  Future<Captcha> captcha() async {
    final r = await _dio.get('/api/auth/captcha');
    final j = r.data as Map<String, dynamic>;
    return Captcha.fromDataUri(id: j['captchaId'] as String, dataUri: j['image'] as String);
  }

  Future<AuthResponseModel> login(String email, String password, String captchaId, String captchaAnswer) async {
    final r = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
      'captchaId': captchaId,
      'captchaAnswer': captchaAnswer,
    });
    return AuthResponseModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<AuthResponseModel> register(RegisterData d) async {
    final r = await _dio.post('/api/auth/register', data: {
      'name': d.name,
      'cpf': d.cpf,
      'email': d.email,
      'password': d.password,
      'team': d.team,
    });
    return AuthResponseModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<AuthResponseModel> refresh(String refreshToken) async {
    final r = await _dio.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
    return AuthResponseModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> logout() => _dio.post('/api/auth/logout');

  Future<User> me() async {
    final r = await _dio.get('/api/auth/me');
    return UserModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<User> updateProfile(String name, String team) async {
    final r = await _dio.put('/api/auth/me', data: {'name': name, 'team': team});
    return UserModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> changePassword(String current, String next) =>
      _dio.post('/api/auth/change-password', data: {'currentPassword': current, 'newPassword': next});

  // ---- Autenticador (MFA) ----
  Future<MfaStatus> mfaStatus() async {
    final j = (await _dio.get('/api/mfa/status')).data as Map<String, dynamic>;
    return MfaStatus(enabled: j['enabled'] as bool, recoveryCodesLeft: j['recoveryCodesLeft'] as int);
  }

  Future<MfaSetup> mfaSetup() async {
    final j = (await _dio.post('/api/mfa/setup')).data as Map<String, dynamic>;
    return MfaSetup(secret: j['secret'] as String, otpAuthUri: j['otpAuthUri'] as String);
  }

  List<String> _codes(Object? data) =>
      ((data as Map<String, dynamic>)['recoveryCodes'] as List).map((e) => e.toString()).toList();

  Future<List<String>> mfaEnable(String code) async => _codes((await _dio.post('/api/mfa/enable', data: {'code': code})).data);

  Future<void> mfaDisable(String password) => _dio.post('/api/mfa/disable', data: {'password': password});

  Future<List<String>> mfaNewRecoveryCodes(String password) async =>
      _codes((await _dio.post('/api/mfa/recovery-codes', data: {'password': password})).data);
}

class MatchRemoteDataSource {
  MatchRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<Match>> list({required String team, required String status, String? search}) async {
    final r = await _dio.get('/api/matches', queryParameters: {
      'team': team,
      'status': status,
      if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
    });
    return (r.data as List).map((e) => MatchModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SectorAvailability>> sectors(int matchId) async {
    final r = await _dio.get('/api/matches/$matchId/sectors');
    return (r.data as List).map((e) => SectorModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SeatMap> seats(int matchId, Sector sector) async {
    final r = await _dio.get('/api/matches/$matchId/seats', queryParameters: {'sector': sector.apiValue});
    return SeatMapModel.fromJson(r.data as Map<String, dynamic>);
  }
}

class PaymentRemoteDataSource {
  PaymentRemoteDataSource(this._dio);
  final Dio _dio;

  Future<PaymentIntent> createIntent({
    required int matchId,
    required Sector sector,
    required PaymentMethod method,
    String? memberCode,
    int? seatRow,
    int? seatNumber,
  }) async {
    final r = await _dio.post('/api/payments/intents', data: {
      'matchId': matchId,
      'sector': sector.apiValue,
      'method': method.apiValue,
      'memberCode': memberCode,
      if (seatRow != null) 'seatRow': seatRow,
      if (seatNumber != null) 'seatNumber': seatNumber,
    });
    return PaymentModel.intentFromJson(r.data as Map<String, dynamic>);
  }

  Future<PurchaseResult> confirm({
    required PaymentIntent intent,
    required String code,
    String? cardToken,
  }) async {
    // JSON: nonce da compra + código de 6 dígitos do autenticador (ou de recuperação) + token do cartão.
    final r = await _dio.post('/api/payments/intents/${intent.id}/confirm', data: {
      'nonce': intent.nonce,
      'code': code,
      if (cardToken != null) 'cardToken': cardToken,
    });
    final j = r.data as Map<String, dynamic>;
    return PurchaseResult(
      ticket: PaymentModel.ticketFromJson(j['ticket'] as Map<String, dynamic>),
      pixPayload: j['pixPayload'] as String?,
    );
  }

  Future<SubscriptionResult> subscribe({
    required int planPercent,
    required PaymentMethod method,
    String? cardToken,
  }) async {
    final r = await _dio.post('/api/membership/subscribe', data: {
      'plan': planPercent,
      'method': method.apiValue,
      'cardToken': cardToken,
    });
    final j = r.data as Map<String, dynamic>;
    return SubscriptionResult(memberCode: j['memberCode'] as String, pixPayload: j['pixPayload'] as String?);
  }

  Future<List<Ticket>> tickets() async {
    final r = await _dio.get('/api/tickets');
    return (r.data as List).map((e) => PaymentModel.ticketFromJson(e as Map<String, dynamic>)).toList();
  }
}

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._dio);
  final Dio _dio;

  Future<ChatReply> send(String message) async {
    final r = await _dio.post('/api/chat', data: {'message': message});
    final data = r.data as Map<String, dynamic>;
    return ChatReply(
      reply: data['reply'] as String? ?? '',
      suggestions: ((data['suggestions'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class AdminRemoteDataSource {
  AdminRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<AdminTicket>> tickets() async {
    final r = await _dio.get('/api/admin/tickets');
    return (r.data as List).map((e) {
      final j = e as Map<String, dynamic>;
      return AdminTicket(
        matchName: j['matchName'] as String,
        sector: j['sector'] as String,
        code: j['code'] as String,
        amount: (j['amount'] as num).toDouble(),
        issuedAt: DateTime.parse(j['issuedAt'] as String),
        userId: j['userId'] as String,
        seatRow: j['seatRow'] as int?,
        seatNumber: j['seatNumber'] as int?,
      );
    }).toList();
  }
}
