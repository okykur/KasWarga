import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/constants/app_constants.dart';

class PickedImage {
  const PickedImage({
    required this.name,
    required this.extension,
    required this.bytes,
  });

  final String name;
  final String extension;
  final Uint8List bytes;
}

class FileUploadService {
  const FileUploadService._();

  static Future<PickedImage?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;

    final file = result.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(extension)) {
      throw const FormatException(
        'File harus berupa gambar JPG, PNG, atau WebP.',
      );
    }
    if (file.size > AppConstants.maxImageSizeBytes) {
      throw const FormatException('Ukuran gambar maksimal 5 MB.');
    }
    if (file.bytes == null) {
      throw const FormatException('File gambar tidak dapat dibaca.');
    }
    return PickedImage(
      name: file.name,
      extension: extension == 'jpeg' ? 'jpg' : extension,
      bytes: file.bytes!,
    );
  }
}
