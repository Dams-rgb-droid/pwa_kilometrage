import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

enum DeliveryResult { shared, saved, cancelled }

/// Fonction JavaScript définie dans web/index.html (Web Share API).
@JS('kmShareFile')
external JSPromise<JSString> _kmShareFile(
  JSString fileName,
  JSString mimeType,
  JSUint8Array bytes,
);

/// Fonction JavaScript définie dans web/index.html (sélecteur de fichier).
@JS('kmPickTextFile')
external JSPromise<JSString> _kmPickTextFile();

/// Ouvre le sélecteur de fichiers et retourne le texte du fichier choisi
/// (null si annulé). À appeler directement depuis un geste de l'utilisateur.
Future<String?> pickTextFile() async {
  try {
    final text = (await _kmPickTextFile().toDart).toDart;
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

/// Remet un fichier à l'utilisateur.
///
/// Sur iPhone (application ajoutée à l'écran d'accueil), un téléchargement
/// classique ne fonctionne pas bien : on passe d'abord par la feuille de
/// partage (Enregistrer dans Fichiers, Mail, AirDrop…). Si elle n'est pas
/// disponible, on retombe sur le téléchargement habituel.
Future<DeliveryResult> deliverFile({
  required String name,
  required String extension,
  required String mimeTypeName,
  required MimeType mimeType,
  required Uint8List bytes,
}) async {
  try {
    final outcome = await _kmShareFile(
      '$name.$extension'.toJS,
      mimeTypeName.toJS,
      bytes.toJS,
    ).toDart;
    final value = outcome.toDart;
    if (value == 'shared') return DeliveryResult.shared;
    if (value == 'cancelled') return DeliveryResult.cancelled;
  } catch (_) {
    // Partage indisponible : téléchargement classique ci-dessous.
  }

  await FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: extension,
    mimeType: mimeType,
  );
  return DeliveryResult.saved;
}
