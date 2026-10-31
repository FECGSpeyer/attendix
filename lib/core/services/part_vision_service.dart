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
  PartVisionService(this._client, this._tenantId, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  /// Read lazily, so a missing client is just another failure (null).
  final SupabaseClient Function() _client;

  /// The tenant now (it can change while files are read).
  final int? Function() _tenantId;
  final DateTime Function() _now;

  /// Off for the rest of the session once the function is missing.
  static bool _unavailable = false;

  static const _function = 'part-detect';

  /// For everything of one file: reading, rendering and the request.
  static const timeout = Duration(seconds: 25);

  /// Largest picture sent; the function allows exactly this many bytes.
  static const maxImageBytes = 1500000;
  static const _renderWidth = 1100;

  /// Whether [file] can be looked at: PDFs, and photos (PNG/JPEG) outside
  /// the PWA. In the browser a photo could only be re-encoded on the UI
  /// thread (blocking the page and every deadline), so it keeps the
  /// file-name result there.
  static bool supports(String fileName, {bool web = kIsWeb}) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return true;
    return !web && (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg'));
  }

  /// The tenant now, to pin an upload to (null when it cannot be read).
  int? currentTenant() {
    try {
      return _tenantId();
    } catch (_) {
      return null;
    }
  }

  /// Reads the part of [file] among [instruments]; null when it could not
  /// within [limit] (at most [timeout]). Once [cancelled] says true (file
  /// removed, changed by hand, uploading, page left), no request is started
  /// any more. [tenantId] is the tenant the upload started in (default: the
  /// current one); after a switch to another tenant nothing is sent.
  Future<PartMatch?> detect(
    PlatformFile file,
    List<InstrumentInfo> instruments, {
    Duration? limit,
    bool Function()? cancelled,
    int? tenantId,
  }) async {
    if (_unavailable || instruments.isEmpty || !supports(file.name)) return null;
    final time = limit == null || limit > timeout ? timeout : limit;
    if (time < _minRequestTime) return null;
    _Deadline? deadline;
    try {
      final tenant = tenantId ?? _tenantId();
      if (tenant == null) return null;
      final d = deadline = _Deadline(time, _now, () => (cancelled?.call() ?? false) || currentTenant() != tenant);
      if (d.isOver) return null;
      // The caller gets its answer on time; the work behind it checks the
      // same deadline after every step, so a late render never leads to a
      // (paid) request.
      return await _detect(file, tenant, instruments, d).timeout(time);
    } on FunctionException catch (e) {
      if (e.status == 404) _unavailable = true;
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[part-detect] $e');
      return null;
    } finally {
      deadline?.expire();
    }
  }

  /// Less than this left: no request is started any more.
  static const _minRequestTime = Duration(seconds: 3);

  Future<PartMatch?> _detect(PlatformFile file, int tenantId, List<InstrumentInfo> instruments, _Deadline deadline) async {
    final image = await _firstPage(file, deadline);
    if (image == null || image.length > maxImageBytes) return null;
    final left = deadline.left;
    if (left < _minRequestTime) return null;
    final response = await _client().functions.invoke(_function, body: {
      'tenantId': tenantId,
      'image': base64Encode(image),
    }).timeout(left);
    if (deadline.isOver) return null;
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

  /// Page 1 as a fresh JPEG (PDF rendered, photos decoded and re-encoded);
  /// null as soon as [deadline] is over.
  Future<Uint8List?> _firstPage(PlatformFile file, _Deadline deadline) async {
    final bytes = await _bytes(file);
    if (bytes == null || deadline.isOver) return null;
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      // Never in the browser (see [supports]): in its own isolate.
      final image = await compute(reencodeImage, bytes);
      return deadline.isOver ? null : image;
    }
    final doc = await PdfDocument.openData(bytes);
    try {
      if (deadline.isOver) return null;
      final page = await doc.getPage(1);
      try {
        if (deadline.isOver) return null;
        final image = await page.render(
          width: _renderWidth.toDouble(),
          height: _renderWidth * page.height / page.width,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 70,
        );
        return deadline.isOver ? null : image?.bytes;
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

/// Time left for one file; over once it ran out or the caller gave up.
class _Deadline {
  _Deadline(Duration time, this._now, this._cancelled) : _end = _now().add(time);

  final DateTime Function() _now;
  final DateTime _end;
  final bool Function() _cancelled;
  bool _expired = false;

  void expire() => _expired = true;
  bool get isOver => _expired || _cancelled() || !_now().isBefore(_end);
  Duration get left => isOver ? Duration.zero : _end.difference(_now());
}

/// [bytes] (PNG/JPEG) decoded and written anew as a small JPEG: upright,
/// at most 1100 px wide, without EXIF (GPS, camera) or colour profile.
/// Pictures with more pixels are not decoded at all (memory).
const int maxPhotoPixels = 40 * 1000 * 1000;

Uint8List? reencodeImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    if (info == null || info.width * info.height > maxPhotoPixels) return null;
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
