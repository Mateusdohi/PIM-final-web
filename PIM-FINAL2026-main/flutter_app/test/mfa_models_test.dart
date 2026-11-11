import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ticketfut/data/models/models.dart';
import 'package:ticketfut/domain/entities/mfa.dart';

void main() {
  test('Captcha decodifica o data URI SVG devolvido pela API', () {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg"></svg>';
    final c = Captcha.fromDataUri(id: 'abc', dataUri: 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}');
    expect(c.id, 'abc');
    expect(utf8.decode(c.svg), svg);
  });

  test('UserModel lê mfaEnabled (e assume false se faltar)', () {
    Map<String, dynamic> j(Map<String, dynamic> extra) => {
          'id': 'u', 'name': 'Ana', 'email': 'a@a.com', 'team': 'palmeiras',
          'planPercent': 0, 'planName': 'Sem plano', 'memberCode': null, 'role': 'User', ...extra,
        };
    expect(UserModel.fromJson(j({'mfaEnabled': true})).mfaEnabled, isTrue);
    expect(UserModel.fromJson(j({})).mfaEnabled, isFalse);
  });
}
