import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum NotesImportFailure { unsupportedType, unreadableText, unknown }

class NotesImportException implements Exception {
  const NotesImportException(this.failure);
  final NotesImportFailure failure;
}

class NotesFileTextExtractor {
  static const _supportedExtensions = <String>{
    'txt',
    'md',
    'markdown',
    'pdf',
    'docx',
  };

  static Future<String?> pickAndExtractText() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      withData: true,
      allowedExtensions: _supportedExtensions.toList(),
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    if (extension.isNotEmpty && !_supportedExtensions.contains(extension)) {
      throw const NotesImportException(NotesImportFailure.unsupportedType);
    }

    final bytes = await _readBytes(file);
    if (bytes.isEmpty) {
      throw const NotesImportException(NotesImportFailure.unreadableText);
    }

    final text = switch (extension) {
      'pdf' => _extractPdfText(bytes),
      'docx' => _extractDocxText(bytes),
      _ => _decodeText(bytes),
    };
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      throw const NotesImportException(NotesImportFailure.unreadableText);
    }
    return cleaned;
  }

  static Future<Uint8List> _readBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes!;
    final path = file.path;
    if (path == null || path.isEmpty) return Uint8List(0);
    final f = File(path);
    if (!await f.exists()) return Uint8List(0);
    return f.readAsBytes();
  }

  static String _extractPdfText(Uint8List bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(doc).extractText();
    } finally {
      doc.dispose();
    }
  }

  static String _decodeText(Uint8List bytes) {
    final decoders = <String Function()>[
      () => utf8.decode(bytes, allowMalformed: true),
      () => latin1.decode(bytes),
      () => ascii.decode(bytes),
    ];
    for (final decode in decoders) {
      final text = decode();
      if (text.trim().isNotEmpty) return text;
    }
    return '';
  }

  static String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    ArchiveFile? documentXml;
    for (final file in archive.files) {
      if (file.name.toLowerCase() == 'word/document.xml') {
        documentXml = file;
        break;
      }
    }
    if (documentXml == null) return '';
    final xmlBytes = List<int>.from(documentXml.content);
    final xmlText = utf8.decode(xmlBytes, allowMalformed: true);
    if (xmlText.trim().isEmpty) return '';

    var text = xmlText
        .replaceAllMapped(RegExp(r'</w:p>', caseSensitive: false), (_) => '\n')
        .replaceAllMapped(
            RegExp(r'<w:tab[^>]*/>', caseSensitive: false), (_) => '\t')
        .replaceAllMapped(RegExp(r'<[^>]+>'), (_) => '');

    text = _decodeXmlEntities(text);
    text = text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text;
  }

  static String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#10;', '\n')
        .replaceAll('&#13;', '\r')
        .replaceAll('&#9;', '\t')
        .replaceAll('&#160;', ' ');
  }
}
