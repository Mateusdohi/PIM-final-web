import 'package:equatable/equatable.dart';

import 'payment.dart';

/// Cadeira já ocupada: vendida ou reservada por outra compra em andamento.
class TakenSeat extends Equatable {
  const TakenSeat(this.row, this.number, {required this.sold});
  final int row;
  final int number;
  final bool sold; // false = reservada (compra em andamento)

  @override
  List<Object?> get props => [row, number, sold];
}

/// Mapa de assentos de um setor (GET /api/matches/{id}/seats).
/// Cada fileira tem [rowSizes] cadeiras, centralizadas em [seatsPerRow] posições.
class SeatMap extends Equatable {
  const SeatMap({
    required this.sector,
    required this.rows,
    required this.seatsPerRow,
    required this.available,
    required this.reason,
    required this.taken,
    required this.rowSizes,
  });

  final Sector sector;
  final int rows;
  final int seatsPerRow;
  final bool available;
  final String? reason;
  final List<TakenSeat> taken;
  final List<int> rowSizes;

  int sizeOf(int row) => (row >= 1 && row <= rowSizes.length) ? rowSizes[row - 1] : seatsPerRow;

  /// Número da primeira cadeira da fileira (as cadeiras ficam centralizadas).
  int firstNumber(int row) => (seatsPerRow - sizeOf(row)) ~/ 2 + 1;

  TakenSeat? takenAt(int row, int number) {
    for (final t in taken) {
      if (t.row == row && t.number == number) return t;
    }
    return null;
  }

  @override
  List<Object?> get props => [sector, rows, seatsPerRow, available, reason, taken, rowSizes];
}
