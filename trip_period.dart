enum TripPeriod {
  week,
  month,
  year;

  String get label => switch (this) {
    TripPeriod.week => 'Semaine',
    TripPeriod.month => 'Mois',
    TripPeriod.year => 'Année',
  };
}

class TripPeriodRange {
  const TripPeriodRange({required this.start, required this.end});

  /// Les bornes sont calculées avec le constructeur `DateTime(y, m, d)` et non
  /// avec `Duration`, pour rester exactes lors des changements d'heure.
  factory TripPeriodRange.forDate(TripPeriod period, DateTime date) {
    switch (period) {
      case TripPeriod.week:
        final start = DateTime(
          date.year,
          date.month,
          date.day - (date.weekday - DateTime.monday),
        );
        return TripPeriodRange(
          start: start,
          end: DateTime(start.year, start.month, start.day + 7),
        );
      case TripPeriod.month:
        return TripPeriodRange(
          start: DateTime(date.year, date.month),
          end: DateTime(date.year, date.month + 1),
        );
      case TripPeriod.year:
        return TripPeriodRange(
          start: DateTime(date.year),
          end: DateTime(date.year + 1),
        );
    }
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}
