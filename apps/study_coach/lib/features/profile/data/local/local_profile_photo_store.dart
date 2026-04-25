import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class LocalProfilePhotoStore {
  Future<String?> getPhotoPath(String uid) async {
    final file = await _photoFileFor(uid);
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<String> savePhoto({
    required String uid,
    Uint8List? fileBytes,
    String? filePath,
    String? fileName,
  }) async {
    final target = await _photoFileFor(uid, fileName: fileName);
    await target.parent.create(recursive: true);
    if (fileBytes != null && fileBytes.isNotEmpty) {
      await target.writeAsBytes(fileBytes, flush: true);
      return target.path;
    }
    if (filePath != null && filePath.isNotEmpty) {
      final source = File(filePath);
      if (await source.exists()) {
        await source.copy(target.path);
        return target.path;
      }
    }
    throw Exception('No local image data available to save.');
  }

  Future<void> clearPhoto(String uid) async {
    final file = await _photoFileFor(uid);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _photoFileFor(String uid, {String? fileName}) async {
    final dir = await getApplicationSupportDirectory();
    final safeUid = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final extension = _extractExtension(fileName);
    return File('${dir.path}/profile_photos/$safeUid/avatar.$extension');
  }

  String _extractExtension(String? fileName) {
    if (fileName == null || fileName.isEmpty) return 'jpg';
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return 'jpg';
    final ext = fileName.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext)) {
      return ext;
    }
    return 'jpg';
  }
}
