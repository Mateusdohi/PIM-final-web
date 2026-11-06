import 'package:dio/dio.dart';

import '../../../domain/entities/payment.dart';
import '../../models/models.dart';
import '../../models/seat_model.dart';
import '../../../domain/entities/seat.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/user.dart';

/// Falam com o backend C#. Lançam DioException; os repositórios convertem em Result.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);
  final Dio _dio;

  Future<AuthResponseModel> login(String email, String password) async {
    final r = await _dio.post('/api/auth/login', data: {'email': email, 'password': password});
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

  /// Envia a selfie (multipart). O backend repassa ao microsserviço Python.
  Future<User> enrollFace(String imagePath) async {
    final form = FormData.fromMap({
      'consent': 'true',
      'selfie': await MultipartFile.fromFile(imagePath, filename: 'selfie.jpg'),
    });
    final r = await _dio.post('/api/auth/face/enroll', data: form);
    return UserModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteFace() => _dio.delete('/api/auth/face');

  Future<User> updateProfile(String name, String team) async {
    final r = await _dio.put('/api/auth/me', data: {'name': name, 'team': team});
    return UserModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> changePassword(String current, String next) =>
      _dio.post('/api/auth/change-password', data: {'currentPassword': current, 'newPassword': next});
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
    required String selfiePath,
    String? livenessSelfiePath,
    String? cardToken,
  }) async {
    final form = FormData.fromMap({
      'nonce': intent.nonce,
      if (cardToken != null) 'cardToken': cardToken,
      'selfie': await MultipartFile.fromFile(selfiePath, filename: 'selfie.jpg'),
      if (livenessSelfiePath != null)
        'livenessSelfie': await MultipartFile.fromFile(livenessSelfiePath, filename: 'liveness.jpg'),
    });
    final r = await _dio.post('/api/payments/intents/${intent.id}/confirm', data: form);
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
