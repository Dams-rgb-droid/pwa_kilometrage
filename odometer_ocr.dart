import 'dart:js_interop';

/// Fonctions JavaScript définies dans web/index.html (Tesseract.js).
@JS('kmPickPhoto')
external JSPromise<JSString> _kmPickPhoto();

@JS('kmRecognizeOdometer')
external JSPromise<JSString> _kmRecognizeOdometer();

enum OcrStatus { ok, none, error }

class OcrResult {
  const OcrResult(this.status, {this.km, this.message});
  final OcrStatus status;
  final double? km;
  final String? message;
}

/// Ouvre l'appareil photo (ou la photothèque). À appeler directement depuis un
/// toucher de l'utilisateur. Retourne false si l'utilisateur annule.
Future<bool> pickOdometerPhoto() async {
  try {
    return (await _kmPickPhoto().toDart).toDart == 'OK';
  } catch (_) {
    return false;
  }
}

/// Lit le kilométrage sur la photo choisie.
Future<OcrResult> recognizeOdometer() async {
  try {
    final raw = (await _kmRecognizeOdometer().toDart).toDart;
    if (raw.startsWith('OK:')) {
      final km = double.tryParse(raw.substring(3));
      if (km != null) return OcrResult(OcrStatus.ok, km: km);
    }
    if (raw.startsWith('NONE')) {
      final bar = raw.indexOf('|');
      return OcrResult(
        OcrStatus.none,
        message: bar >= 0 ? raw.substring(bar + 1) : null,
      );
    }
    return OcrResult(OcrStatus.error, message: raw.replaceFirst('ERROR:', ''));
  } catch (error) {
    return OcrResult(OcrStatus.error, message: '$error');
  }
}
