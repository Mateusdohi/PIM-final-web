import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cart/cart_service.dart';
import '../../core/di/injection.dart';
import '../../core/error/failures.dart';
import '../../core/router/route_args.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/seat.dart';
import '../../domain/usecases/matches/match_usecases.dart';
import '../cart/cart_button.dart';

/// Escolha da cadeira no setor (mapa de assentos igual ao do web).
class SeatsPage extends StatefulWidget {
  const SeatsPage({super.key, required this.args});
  final SeatsArgs args;

  @override
  State<SeatsPage> createState() => _SeatsPageState();
}

class _SeatsPageState extends State<SeatsPage> {
  late Future<Result<SeatMap>> _future = _load();
  int? _row;
  int? _number;

  Future<Result<SeatMap>> _load() => sl<GetSeatsUseCase>()(widget.args.match.id, widget.args.sector);

  void _reload() => setState(() {
        _row = null;
        _number = null;
        _future = _load();
      });

  void _continue() {
    context.push('/checkout',
        extra: CheckoutArgs(
          match: widget.args.match,
          sector: widget.args.sector,
          seatRow: _row,
          seatNumber: _number,
        ));
  }

  void _addToCart() {
    final error = sl<CartService>().add(CartItem(
      match: widget.args.match,
      sector: widget.args.sector,
      row: _row!,
      number: _number!,
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Adicionado ao carrinho.')));
    if (error != null) return;
    setState(() {
      _row = null;
      _number = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.args.match;
    return Scaffold(
      appBar: AppBar(title: Text('SETOR ${widget.args.sector.label}'), actions: const [CartButton()]),
      body: SafeArea(
        child: FutureBuilder<Result<SeatMap>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snap.data;
            if (result == null) return _error('Não foi possível carregar os assentos.');
            return result.fold((f) => _error(f.message), (map) => _content(context, match.title, map));
          },
        ),
      ),
    );
  }

  Widget _error(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reload, child: const Text('TENTAR NOVAMENTE')),
          ]),
        ),
      );

  Widget _content(BuildContext context, String title, SeatMap map) {
    if (!map.available) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.block, size: 48, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(map.reason ?? 'Este setor não está disponível para você.', textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    final selected = _row != null && _number != null;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(children: [
          Text(title.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text('Toque numa cadeira livre. A fileira 1 é a mais perto do campo.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
      const _Legend(),
      Expanded(
        child: LayoutBuilder(
          builder: (context, c) => ListenableBuilder(
            listenable: sl<CartService>(),
            builder: (context, _) => SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: _SeatGrid(
                  map: map,
                  sector: widget.args.sector,
                  matchId: widget.args.match.id,
                  width: c.maxWidth,
                  selectedRow: _row,
                  selectedNumber: _number,
                  onSelect: (r, n) => setState(() {
                    _row = r;
                    _number = n;
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.borderSoft))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            liveRegion: true,
            child: Text(
              selected ? 'Fileira $_row · Cadeira $_number' : 'Nenhuma cadeira escolhida',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, color: selected ? AppColors.brand : AppColors.muted),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(Fmt.money(widget.args.match.price),
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selected ? _addToCart : null,
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('CARRINHO'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: selected ? _continue : null, child: const Text('COMPRAR AGORA'))),
          ]),
        ]),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Wrap(spacing: 10, runSpacing: 4, alignment: WrapAlignment.center, children: [
          _LegendItem('Livre', _SeatStyle.free),
          _LegendItem('Escolhida', _SeatStyle.selected),
          _LegendItem('No carrinho', _SeatStyle.cart),
          _LegendItem('Reservada', _SeatStyle.held),
          _LegendItem('Ocupada', _SeatStyle.sold),
        ]),
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.style);
  final String label;
  final _SeatStyle style;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: style.fill, border: Border.all(color: style.border), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}

enum _SeatStyle {
  free(Color(0xFFD9F0E2), AppColors.brand),
  selected(AppColors.brand, AppColors.brandDark),
  cart(Color(0xFF9DB4E0), AppColors.navy),
  held(Color(0xFFF2C94C), Color(0xFFB8860B)),
  sold(Color(0xFFC3CAD5), Color(0xFFAAB2C2));

  const _SeatStyle(this.fill, this.border);
  final Color fill;
  final Color border;
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
    required this.map,
    required this.sector,
    required this.matchId,
    required this.width,
    required this.selectedRow,
    required this.selectedNumber,
    required this.onSelect,
  });

  final SeatMap map;
  final Sector sector;
  final int matchId;
  final double width;
  final int? selectedRow;
  final int? selectedNumber;
  final void Function(int row, int number) onSelect;

  // Mesma regra do web: Oeste e Leste desenham cada fileira como uma coluna.
  bool get _lateral => sector == Sector.oeste || sector == Sector.leste;

  @override
  Widget build(BuildContext context) {
    // Norte: fileira 1 embaixo, campo embaixo.   Sul: campo em cima, fileira 1 em cima.
    // Oeste: fileira 1 à direita, campo à direita.   Leste: campo à esquerda, fileira 1 à esquerda.
    var order = [for (var r = 1; r <= map.rows; r++) r];
    if (sector == Sector.norte || sector == Sector.oeste) order = order.reversed.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: _lateral ? _sideLayout(order) : _frontLayout(order),
    );
  }

  Widget _field({required bool vertical, required double size}) => Container(
        width: vertical ? 30 : size,
        height: vertical ? size : null,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFD9F0E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brand),
        ),
        child: RotatedBox(
          quarterTurns: vertical ? (sector == Sector.oeste ? 1 : 3) : 0,
          child: const Text('CAMPO',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 11)),
        ),
      );

  /// Norte e Sul: fileiras horizontais.
  Widget _frontLayout(List<int> order) {
    const labelWidth = 26.0;
    // Mesmo tamanho de cadeira do Leste/Oeste; se não couber na largura, rola para o lado.
    const slot = 26.0;
    final seat = slot - 2;
    final field = _field(vertical: false, size: slot * map.seatsPerRow + labelWidth);

    final grid = Column(mainAxisSize: MainAxisSize.min, children: [
      if (sector == Sector.sul) ...[field, const SizedBox(height: 8)],
      for (final r in order)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: labelWidth,
              child: Text('$r', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ),
            for (var n = 1; n <= map.seatsPerRow; n++) SizedBox(width: slot, height: slot, child: _seatAt(r, n, seat)),
          ]),
        ),
      if (sector == Sector.norte) ...[const SizedBox(height: 8), field],
    ]);
    return SizedBox(
      width: width - 16,
      child: _CenteredHScroll(child: grid),
    );
  }

  /// Oeste e Leste: cada fileira vira uma coluna e o campo fica ao lado.
  Widget _sideLayout(List<int> order) {
    const fieldWidth = 30.0;
    final slot = ((width - fieldWidth - 24) / map.rows).floorToDouble().clamp(10.0, 26.0);
    final seat = slot - 2;
    final height = slot * map.seatsPerRow;
    final field = _field(vertical: true, size: height);

    final columns = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in order)
        Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: slot,
            height: height,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var n = 1; n <= map.seatsPerRow; n++) SizedBox(width: slot, height: slot, child: _seatAt(r, n, seat)),
            ]),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: slot,
            child: Text('$r', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
        ]),
    ]);

    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (sector == Sector.leste) ...[field, const SizedBox(width: 8)],
      columns,
      if (sector == Sector.oeste) ...[const SizedBox(width: 8), field],
    ]);
  }

  Widget _seatAt(int r, int n, double size) {
    final first = map.firstNumber(r);
    final last = first + map.sizeOf(r) - 1;
    if (n < first || n > last) return const SizedBox.shrink(); // fora do desenho do estádio

    final taken = map.takenAt(r, n);
    final inCart = sl<CartService>().contains(matchId, sector, r, n);
    final isSelected = selectedRow == r && selectedNumber == n;
    final style = isSelected
        ? _SeatStyle.selected
        : inCart
            ? _SeatStyle.cart
            : taken == null
                ? _SeatStyle.free
                : (taken.sold ? _SeatStyle.sold : _SeatStyle.held);
    final free = taken == null && !inCart;
    final state = isSelected
        ? 'escolhida'
        : inCart
            ? 'no carrinho'
            : taken == null
                ? 'livre'
                : taken.sold
                    ? 'ocupada'
                    : 'reservada';

    return Semantics(
      button: free,
      selected: isSelected,
      label: 'Fileira $r, cadeira $n, $state',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: free ? () => onSelect(r, n) : null,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: style.fill,
              border: Border.all(color: style.border, width: 1),
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rolagem horizontal que já abre no meio (as cadeiras do centro ficam à vista).
class _CenteredHScroll extends StatefulWidget {
  const _CenteredHScroll({required this.child});
  final Widget child;

  @override
  State<_CenteredHScroll> createState() => _CenteredHScrollState();
}

class _CenteredHScrollState extends State<_CenteredHScroll> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpTo(_controller.position.maxScrollExtent / 2);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(controller: _controller, scrollDirection: Axis.horizontal, child: widget.child);
}
