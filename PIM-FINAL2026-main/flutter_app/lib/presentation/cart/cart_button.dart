import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cart/cart_service.dart';
import '../../core/di/injection.dart';

/// Ícone do carrinho com o número de ingressos (vai na barra de cima).
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = sl<CartService>();
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) => IconButton(
        tooltip: 'Carrinho, ${cart.count} ingresso(s)',
        onPressed: () => context.push('/cart'),
        icon: Badge(
          isLabelVisible: cart.count > 0,
          label: Text('${cart.count}'),
          child: const Icon(Icons.shopping_cart_outlined),
        ),
      ),
    );
  }
}
