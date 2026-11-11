import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Captcha do login: imagem SVG gerada pela API + id (cada captcha vale uma única tentativa).
class Captcha extends Equatable {
  const Captcha({required this.id, required this.svg});
  final String id;
  final Uint8List svg;

  /// Converte o "data:image/svg+xml;base64,..." devolvido pela API.
  factory Captcha.fromDataUri({required String id, required String dataUri}) =>
      Captcha(id: id, svg: base64Decode(dataUri.substring(dataUri.indexOf(',') + 1)));

  @override
  List<Object?> get props => [id];
}

/// Estado do autenticador (MFA) da conta.
class MfaStatus extends Equatable {
  const MfaStatus({required this.enabled, required this.recoveryCodesLeft});
  final bool enabled;
  final int recoveryCodesLeft;

  @override
  List<Object?> get props => [enabled, recoveryCodesLeft];
}

/// Início da ativação: a mesma chave como texto (para digitar no app autenticador) e como otpauth:// (para o QR Code).
class MfaSetup extends Equatable {
  const MfaSetup({required this.secret, required this.otpAuthUri});
  final String secret;
  final String otpAuthUri;

  @override
  List<Object?> get props => [secret, otpAuthUri];
}
