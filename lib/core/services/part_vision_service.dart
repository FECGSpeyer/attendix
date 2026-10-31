import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/instrument_matcher.dart';

/// Fallback for files whose part the file name does not reveal: the first
/// page is rendered small and the `part-detect` Edge Function reads the part
/// name printed on it (see `supabase/functions/part-detect`). Only the image
/// and the group names leave the device; nothing is stored.
///
/// Every failure (no network, function not deployed, unreadable PDF) yields
/// null, so the upload simply keeps the file-name result.
class PartVisionService {
  PartVisionService(this._client);

  /// Read lazily, so a missing client is just another failure (null).
  final SupabaseClient Function() _client;

  /// Off for the rest of the session once the function is missing.
  static bool _unavailable = false;

  static const _function = 'part-detect';
  static const _timeout = Duration(seconds: 20);
  static const _maxImageBytes = 1500 * 1024;
  static const _renderWidth = 1100.0;

  /// Whether [file] can be looked at (PDF or image).
  static bool supports(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') || lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg');
  }

  /// Reads the part of [file] among [instruments]; null when it could not.
  Future<PartMatch?> detect(PlatformFile file, List<InstrumentInfo> instruments) async {
    if (_unavailable || instruments.isEmpty || !supports(file.name)) return null;
    try {
      final image = await _firstPage(file);
      if (image == null || image.bytes.length > _maxImageBytes) return null;
      final response = await _client().functions
          .invoke(_function, body: {
            'image': base64Encode(image.bytes),
            'mime': image.mime,
            'fileName': file.name,
            'groups': [
              for (final i in instruments) {'id': i.id, 'name': i.name},
            ],
          })
          .timeout(_timeout);
      return parseResponse(response.data, instruments);
    } on FunctionException catch (e) {
      if (e.status == 404) _unavailable = true;
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[part-detect] $e');
      return null;
    }
  }

  /// The function's answer as a match; only ids of [instruments] count.
  static PartMatch? parseResponse(dynamic data, List<InstrumentInfo> instruments) {
    dynamic map = data;
    if (data is String) {
      try {
        map = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    if (map is! Map) return null;
    final raw = map['groupId'];
    final id = raw is int ? raw : int.tryParse('$raw');
    if (id == null || !instruments.any((i) => i.id == id)) return null;
    final label = map['label'];
    return PartMatch(
      instrumentId: id,
      confidence: map['confidence'] == 'high' ? MatchConfidence.sure : MatchConfidence.unsure,
      term: label is String && label.trim().isNotEmpty ? label.trim() : null,
      byVision: true,
    );
  }

  Future<({Uint8List bytes, String mime})?> _firstPage(PlatformFile file) async {
    final bytes = await _bytes(file);
    if (bytes == null) return null;
    final lower = file.name.toLowerCase();
    if (!lower.endsWith('.pdf')) {
      return (bytes: bytes, mime: lower.endsWith('.png') ? 'image/png' : 'image/jpeg');
    }
    final doc = await PdfDocument.openData(bytes);
    try {
      final page = await doc.getPage(1);
      try {
        final height = _renderWidth * page.height / page.width;
        final image = await page.render(
          width: _renderWidth,
          height: height,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 70,
        );
        return image == null ? null : (bytes: image.bytes, mime: 'image/jpeg');
      } finally {
        await page.close();
      }
    } finally {
      await doc.close();
    }
  }

  static Future<Uint8List?> _bytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (kIsWeb || file.path == null) return null;
    return File(file.path!).readAsBytes();
  }
}

final partVisionServiceProvider = Provider<PartVisionService>((ref) {
  return PartVisionService(() => ref.read(supabaseClientProvider));
});
