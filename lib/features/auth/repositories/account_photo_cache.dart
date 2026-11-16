import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class AccountPhotoCache {
  AccountPhotoCache({this.directory = getApplicationSupportDirectory});

  final Future<Directory> Function() directory;

  Future<File?> _file(String userId, String? providerUrl) async {
    if (kIsWeb || !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) return null;
    final root = await directory();
    final kind = providerUrl == null ? 'custom' : 'provider';
    return File('${root.path}/account-avatars/$userId.$kind');
  }

  Future<Uint8List?> read(
    String userId, {
    String? providerUrl,
    Duration? maxAge,
  }) async {
    try {
      final file = await _file(userId, providerUrl);
      if (file == null || !await file.exists()) return null;
      if (maxAge != null &&
          DateTime.now().difference(await file.lastModified()) > maxAge) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (providerUrl == null) return bytes;
      // La URL se guarda junto con la imagen en un solo archivo reemplazable.
      final separator = bytes.indexOf(10);
      if (separator < 0 ||
          utf8.decode(bytes.sublist(0, separator)) != providerUrl) {
        return null;
      }
      return Uint8List.sublistView(bytes, separator + 1);
    } on Exception {
      return null;
    }
  }

  Future<void> write(
    String userId,
    Uint8List bytes, {
    String? providerUrl,
  }) async {
    File? temporary;
    try {
      final file = await _file(userId, providerUrl);
      if (file == null) return;
      await file.parent.create(recursive: true);
      temporary = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      final contents = providerUrl == null
          ? bytes
          : (BytesBuilder(copy: false)
                  ..add(utf8.encode('$providerUrl\n'))
                  ..add(bytes))
                .takeBytes();
      await temporary.writeAsBytes(contents, flush: true);
      await temporary.rename(file.path);
    } on Exception {
      // Una falla en disco no invalida la foto disponible en el servidor.
      try {
        await temporary?.delete();
      } on FileSystemException {
        // Es posible que la escritura ni siquiera haya creado el archivo.
      }
    }
  }

  Future<void> removeCustom(String userId) async {
    try {
      final file = await _file(userId, null);
      if (file != null && await file.exists()) await file.delete();
    } on Exception {
      // La siguiente lectura en línea vuelve a reconciliar la caché.
    }
  }
}
