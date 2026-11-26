/// Formatage et lecture des kilométrages (format français).

/// Affichage : « 12 500,5 » (espace insécable, virgule, décimales inutiles
/// supprimées).
String formatKm(double value) {
  var text = value.abs() < 0.005 ? '0' : value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final negative = text.startsWith('-');
  if (negative) text = text.substring(1);
  final parts = text.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  final decimals = parts.length > 1 ? ',${parts[1]}' : '';
  return '${negative ? '-' : ''}$grouped$decimals';
}

/// Valeur préremplie dans un champ de saisie : « 12500,5 ».
String formatKmInput(double value) {
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return text.replaceFirst('.', ',');
}

/// Valeur pour CSV / tableur français : « 12500,50 », sans séparateur de milliers.
String formatKmPlain(double value) => value.toStringAsFixed(2).replaceFirst('.', ',');

/// Lit un kilométrage saisi (virgule ou point, espaces tolérés).
/// Retourne null si la valeur est vide, invalide, négative ou absurde.
double? parseKm(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite || value < 0 || value > 9999999) {
    return null;
  }
  return value;
}
