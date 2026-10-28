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
