import 'package:flutter/foundation.dart';

import '../../domain/entities/match.dart';
import '../../domain/entities/payment.dart';

/// Um assento guardado no carrinho. Cada item vira uma compra na API.
class CartItem {
  CartItem({required this.match, required this.sector, required this.row, required this.number});
  final Match match;
  final Sector sector;
  final int row;
  final int number;

  /// Motivo da última tentativa de compra que não deu certo.
  String? error;

  bool same(int matchId, Sector s, int r, int n) => match.id == matchId && sector == s && row == r && number == n;
}

/// Carrinho em memória (igual ao web: não é gravado no aparelho).
class CartService extends ChangeNotifier {
  /// Mesmo limite do web: a confirmação aceita poucas compras por minuto.
  static const maxItems = 5;

  final List<CartItem> _items = [];
  String? _owner;

  List<CartItem> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get isEmpty => _items.isEmpty;
  double get total => _items.fold(0, (sum, i) => sum + i.match.price);

  /// Esvazia o carrinho quando quem está logado muda, para a lista não passar ao próximo usuário.
  void bindUser(String? userId) {
    if (_owner == userId) return;
    _owner = userId;
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
    }
  }

  bool contains(int matchId, Sector sector, int row, int number) =>
      _items.any((i) => i.same(matchId, sector, row, number));

  /// Devolve a mensagem de erro, ou null se adicionou.
  String? add(CartItem item) {
    if (_items.length >= maxItems) return 'O carrinho aceita até $maxItems ingressos.';
    if (contains(item.match.id, item.sector, item.row, item.number)) return 'Esse assento já está no carrinho.';
    _items.add(item);
    notifyListeners();
    return null;
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  void touch() => notifyListeners();
}
