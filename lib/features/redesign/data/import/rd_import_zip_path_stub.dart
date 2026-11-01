import 'package:archive/archive.dart';

/// Web: a picked ZIP always comes with its bytes, never with a path.
InputStreamBase? rdOpenZipPath(String path) => null;

/// Web: no native zlib; the caller unpacks in Dart with a limit.
List<int>? rdInflateAtMost(List<int> data, int limit) => null;
