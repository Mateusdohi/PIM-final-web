import '../../domain/entities/match.dart';
import '../../domain/entities/payment.dart';

class FaceEnrollArgs {
  const FaceEnrollArgs({this.planPercent = 0, this.fromRegistration = false});
  final int planPercent;
  final bool fromRegistration;
}

class PlansArgs {
  const PlansArgs({this.initialPlan = 5, this.fromRegistration = false});
  final int initialPlan;
  final bool fromRegistration;
}

class SeatsArgs {
  const SeatsArgs({required this.match, required this.sector});
  final Match match;
  final Sector sector;
}

class CheckoutArgs {
  const CheckoutArgs({required this.match, required this.sector, this.seatRow, this.seatNumber});
  final Match match;
  final Sector sector;
  final int? seatRow;
  final int? seatNumber;
}

class ConfirmationArgs {
  const ConfirmationArgs(this.result);
  final PurchaseResult result;
}
