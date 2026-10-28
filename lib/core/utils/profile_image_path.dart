/// DB_REVIEW_REST (M4): storage keys of person pictures in the `profiles`
/// bucket, identical to Ionic ImageService.updateImage / removeImage.
library;

/// Ionic stores every person picture under the bare player id (upsert).
String profileImageStoragePath(int playerId) => '$playerId';

/// Storage object path of a stored `player.img` public URL, used to delete the
/// file. Handles Ionic keys (`<id>`) as well as legacy Flutter keys
/// (`<tenantId>/<id>.jpg`) and strips query strings (`?quality=20`, `?t=`).
/// Returns null for empty / non-storage URLs (e.g. the default image).
String? profileImagePathFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  final idx = segments.indexOf('profiles');
  if (idx >= 0 && idx < segments.length - 1) {
    return segments.sublist(idx + 1).join('/');
  }
  return null;
}
