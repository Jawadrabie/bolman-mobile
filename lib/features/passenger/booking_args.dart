import '../../data/models.dart';

class SeatsArgs {
  final Trip trip;
  SeatsArgs(this.trip);
}

class PassArgs {
  final Trip trip;
  final String from, to;
  final List<SeatStatus> seats;
  PassArgs(this.trip, this.from, this.to, this.seats);
}
