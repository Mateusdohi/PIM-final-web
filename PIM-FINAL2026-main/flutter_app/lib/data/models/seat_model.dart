import '../../domain/entities/payment.dart';
import '../../domain/entities/seat.dart';

class SeatMapModel {
  SeatMapModel._();

  static SeatMap fromJson(Map<String, dynamic> j) {
    final seatsPerRow = j['seatsPerRow'] as int;
    final sizes = (j['rowSizes'] as List?)?.map((e) => e as int).toList();
    final rows = j['rows'] as int;
    return SeatMap(
      sector: Sector.fromApi(j['sector'] as String),
      rows: rows,
      seatsPerRow: seatsPerRow,
      available: j['available'] as bool,
      reason: j['reason'] as String?,
      taken: ((j['taken'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => TakenSeat(e['row'] as int, e['number'] as int, sold: (e['status'] as String) == 'sold'))
          .toList(),
      rowSizes: sizes ?? List<int>.filled(rows, seatsPerRow),
    );
  }
}
