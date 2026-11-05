import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/error/failures.dart';
import '../../core/router/route_args.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/seat.dart';
import '../../domain/usecases/matches/match_usecases.dart';

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

  @override
  Widget build(BuildContext context) {
    final match = widget.args.match;
    return Scaffold(
      appBar: AppBar(title: Text('SETOR ${widget.args.sector.label}')),
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
          const Text('Toque numa cadeira livre. Use dois dedos para ampliar.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
      const _Legend(),
      Expanded(
        child: LayoutBuilder(
          builder: (context, c) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: _SeatGrid(
                map: map,
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
          FilledButton(onPressed: selected ? _continue : null, child: const Text('CONTINUAR')),
        ]),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Wrap(spacing: 14, runSpacing: 4, alignment: WrapAlignment.center, children: [
          _LegendItem('Livre', _SeatStyle.free),
          _LegendItem('Escolhida', _SeatStyle.selected),
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
  held(Color(0xFFF2C94C), Color(0xFFB8860B)),
  sold(Color(0xFFC3CAD5), Color(0xFFAAB2C2));

  const _SeatStyle(this.fill, this.border);
  final Color fill;
  final Color border;
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
    required this.map,
    required this.width,
    required this.selectedRow,
    required this.selectedNumber,
    required this.onSelect,
  });

  final SeatMap map;
  final double width;
  final int? selectedRow;
  final int? selectedNumber;
  final void Function(int row, int number) onSelect;

  @override
  Widget build(BuildContext context) {
    const labelWidth = 26.0;
    final slot = ((width - labelWidth - 16) / map.seatsPerRow).floorToDouble().clamp(8.0, 26.0);
    final seat = slot - 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Gramado: a fileira 1 é a mais próxima
        Container(
          width: slot * map.seatsPerRow * 0.8 + labelWidth,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFD9F0E2), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.brand)),
          child: const Text('CAMPO', textAlign: TextAlign.center, style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 11)),
        ),
        const SizedBox(height: 8),
        for (var r = 1; r <= map.rows; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: labelWidth,
                child: Text('$r', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ),
              for (var n = 1; n <= map.seatsPerRow; n++)
                SizedBox(width: slot, height: slot, child: _seatAt(r, n, seat)),
            ]),
          ),
      ]),
    );
  }

  Widget _seatAt(int r, int n, double size) {
    final first = map.firstNumber(r);
    final last = first + map.sizeOf(r) - 1;
    if (n < first || n > last) return const SizedBox.shrink(); // fora do desenho do estádio

    final taken = map.takenAt(r, n);
    final isSelected = selectedRow == r && selectedNumber == n;
    final style = isSelected
        ? _SeatStyle.selected
        : taken == null
            ? _SeatStyle.free
            : (taken.sold ? _SeatStyle.sold : _SeatStyle.held);
    final free = taken == null;

    return Semantics(
      button: free,
      selected: isSelected,
      label: 'Fileira $r, cadeira $n, ${isSelected ? 'escolhida' : free ? 'livre' : taken.sold ? 'ocupada' : 'reservada'}',
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
