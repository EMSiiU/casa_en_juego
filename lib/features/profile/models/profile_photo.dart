import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'profile_failure.dart';

class ProfilePhoto {
  const ProfilePhoto(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;

  static const _maxBytes = 2 * 1024 * 1024;

  static Future<ProfilePhoto?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Fotos (JPG, PNG o WebP)',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          uniformTypeIdentifiers: [
            'public.jpeg',
            'public.png',
            'org.webmproject.webp',
          ],
        ),
      ],
    );
    if (file == null) return null;
    _checkSize(await file.length());
    final bytes = await file.readAsBytes();
    _checkSize(bytes.length);
    final type = _contentType(bytes);
    if (type == null) {
      throw const ProfileFailure('Elige una foto JPG, PNG o WebP.');
    }
    try {
      // Decodifica la primera imagen para detectar archivos dañados antes de subirlos.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 96,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const ProfileFailure(
        'No pudimos abrir la foto. Elige otra imagen.',
      );
    }
    return ProfilePhoto(bytes, type);
  }

  static void _checkSize(int length) {
    if (length > _maxBytes) {
      throw const ProfileFailure('La foto debe pesar como máximo 2 MB.');
    }
  }

  static String? _contentType(Uint8List bytes) {
    bool hasSignature(int offset, List<int> signature) {
      return bytes.length >= offset + signature.length &&
          Iterable<int>.generate(signature.length)
              .every((index) => bytes[offset + index] == signature[index]);
    }

    if (hasSignature(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (hasSignature(0, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return 'image/png';
    }
    if (hasSignature(0, const [0x52, 0x49, 0x46, 0x46]) &&
        hasSignature(8, const [0x57, 0x45, 0x42, 0x50])) {
      return 'image/webp';
    }
    return null;
  }
}
