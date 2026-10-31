import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../providers/tenant_providers.dart';
import '../utils/instrument_matcher.dart';

/// Fallback for files whose part the file name does not reveal: the first
/// page is rendered small and the `part-detect` Edge Function reads the part
/// name printed on it (see `supabase/functions/part-detect`). Only that
/// re-encoded picture (no file name, no EXIF/GPS) and the tenant id leave
/// the device; the function checks the account and loads the groups itself.
///
/// Every failure (no network, function not deployed, budget used up,
/// unreadable PDF, too slow) yields null, so the upload simply keeps the
/// file-name result.
class PartVisionService {
  PartVisionService(this._client, this._tenantId);

  /// Read lazily, so a missing client is just another failure (null).
  final SupabaseClient Function() _client;
  final int? Function() _tenantId;

  /// Off for the rest of the session once the function is missing.
  static bool _unavailable = false;

  static const _function = 'part-detect';

  /// For everything of one file: reading, rendering and the request.
  static const timeout = Duration(seconds: 25);

  /// Largest picture sent; the function allows exactly this many bytes.
  static const maxImageBytes = 1500000;
  static const _renderWidth = 1100;

  /// Whether [file] can be looked at (PDF or image).
  static bool supports(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') || lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg');
  }

  /// Reads the part of [file] among [instruments]; null when it could not.
  Future<PartMatch?> detect(PlatformFile file, List<InstrumentInfo> instruments) async {
    if (_unavailable || instruments.isEmpty || !supports(file.name)) return null;
    try {
      final tenantId = _tenantId();
      if (tenantId == null) return null;
      // One deadline for the whole file; resources are closed by the
      // `finally` blocks below even when the deadline hits first.
      return await _detect(file, tenantId, instruments).timeout(timeout);
    } on FunctionException catch (e) {
      if (e.status == 404) _unavailable = true;
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[part-detect] $e');
      return null;
    }
  }

  Future<PartMatch?> _detect(PlatformFile file, int tenantId, List<InstrumentInfo> instruments) async {
    final image = await _firstPage(file);
    if (image == null || image.length > maxImageBytes) return null;
    final response = await _client().functions.invoke(_function, body: {
      'tenantId': tenantId,
      'image': base64Encode(image),
    });
    return parseResponse(response.data, instruments);
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

  /// Page 1 as a fresh JPEG (PDF rendered, photos decoded and re-encoded).
  Future<Uint8List?> _firstPage(PlatformFile file) async {
    final bytes = await _bytes(file);
    if (bytes == null) return null;
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      return kIsWeb ? reencodeImage(bytes) : compute(reencodeImage, bytes);
    }
    final doc = await PdfDocument.openData(bytes);
    try {
      final page = await doc.getPage(1);
      try {
        final image = await page.render(
          width: _renderWidth.toDouble(),
          height: _renderWidth * page.height / page.width,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 70,
        );
        return image?.bytes;
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

/// [bytes] (PNG/JPEG) decoded and written anew as a small JPEG: upright,
/// at most 1100 px wide, without EXIF (GPS, camera) or colour profile.
Uint8List? reencodeImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null; // not a readable picture
  }
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (image.width > PartVisionService._renderWidth) {
    image = img.copyResize(image, width: PartVisionService._renderWidth);
  }
  image
    ..exif = img.ExifData()
    ..iccProfile = null;
  return img.encodeJpg(image, quality: 70);
}

final partVisionServiceProvider = Provider<PartVisionService>((ref) {
  return PartVisionService(
    () => ref.read(supabaseClientProvider),
    () => ref.read(currentTenantIdProvider),
  );
});
