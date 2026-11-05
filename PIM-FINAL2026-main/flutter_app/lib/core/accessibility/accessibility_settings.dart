import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Preferências de acessibilidade do usuário: tamanho do texto e alto contraste.
/// Valem para todo o app e ficam salvas no aparelho.
class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _s;
  static const _kScale = 'a11y_text_scale';
  static const _kContrast = 'a11y_high_contrast';

  static const scales = <double>[1.0, 1.2, 1.4];

  double _textScale = 1.0;
  bool _highContrast = false;

  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  int get scaleIndex => scales.indexOf(_textScale).clamp(0, scales.length - 1);

  Future<void> load() async {
    try {
      final s = double.tryParse(await _s.read(key: _kScale) ?? '');
      if (s != null && scales.contains(s)) _textScale = s;
      _highContrast = (await _s.read(key: _kContrast)) == 'true';
    } catch (_) {
      // sem armazenamento: usa os padrões
    }
  }

  Future<void> setScaleIndex(int i) async {
    _textScale = scales[i.clamp(0, scales.length - 1)];
    notifyListeners();
    await _save(_kScale, _textScale.toString());
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    notifyListeners();
    await _save(_kContrast, v.toString());
  }

  Future<void> _save(String k, String v) async {
    try {
      await _s.write(key: k, value: v);
    } catch (_) {}
  }
}
