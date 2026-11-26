enum TripCategory {
  professional,
  privateUse;

  String get label => switch (this) {
    TripCategory.professional => 'Professionnel',
    TripCategory.privateUse => 'Privé',
  };

  static TripCategory fromJson(Object? value) {
    return TripCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => TripCategory.privateUse,
    );
  }
}

class Trip {
  final String id;
  final DateTime date;
  final double startKm;
  final double? endKm;
  final bool isCompleted;
  final TripCategory category;

  const Trip({
    required this.id,
    required this.date,
    required this.startKm,
    this.endKm,
    this.isCompleted = false,
    this.category = TripCategory.privateUse,
  });

  double get distanceKm => endKm == null ? 0 : endKm! - startKm;

  /// Retourne une copie modifiée. `endKm` à null conserve la valeur actuelle.
  Trip copyWith({
    DateTime? date,
    double? startKm,
    double? endKm,
    bool? isCompleted,
    TripCategory? category,
  }) {
    return Trip(
      id: id,
      date: date ?? this.date,
      startKm: startKm ?? this.startKm,
      endKm: endKm ?? this.endKm,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startKm': startKm,
      'endKm': endKm,
      'isCompleted': isCompleted,
      'category': category.name,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      startKm: (json['startKm'] as num).toDouble(),
      endKm: (json['endKm'] as num?)?.toDouble(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      category: TripCategory.fromJson(json['category']),
    );
  }
}
