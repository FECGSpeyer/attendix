/// Auth e-mails redirect to path routes (`/login`, `/resetPassword`, like
/// Ionic), but the Flutter web app uses the hash URL strategy. Strip such a
/// trailing auth path so the app continues at its base path
/// (`/resetPassword` → `/`, `/app/login` → `/app/`).
String appBasePath(String pathname) {
  const authPaths = ['/resetPassword', '/login'];
  for (final p in authPaths) {
    if (pathname.endsWith(p)) {
      return pathname.substring(0, pathname.length - p.length + 1);
    }
  }
  return pathname.isEmpty ? '/' : pathname;
}

/// Query keys of Supabase auth links that must not survive in the URL.
const Set<String> kAuthLinkParams = {
  'token_hash', 'type', 'code', 'access_token', 'refresh_token',
  'expires_at', 'expires_in', 'token_type', 'provider_token',
  'provider_refresh_token', 'error', 'error_code', 'error_description',
};

/// REVIEW_FIX2: the hash (`#/route?x=1`) to keep after an auth link was
/// handled. A hash route is kept (minus auth params, so a reload does not
/// re-consume the link); a token fragment (`#access_token=…`) is dropped.
/// Returns '' or a string starting with '#'.
String cleanedAuthHash(String hash) {
  final fragment = hash.startsWith('#') ? hash.substring(1) : hash;
  if (!fragment.startsWith('/')) return '';
  final q = fragment.indexOf('?');
  if (q < 0) return '#$fragment';
  final route = fragment.substring(0, q);
  Map<String, String> params;
  try {
    params = Uri.splitQueryString(fragment.substring(q + 1));
  } catch (_) {
    return '#$route';
  }
  final kept = {
    for (final e in params.entries)
      if (!kAuthLinkParams.contains(e.key)) e.key: e.value,
  };
  if (kept.isEmpty) return '#$route';
  return '#$route?${Uri(queryParameters: kept).query}';
}
