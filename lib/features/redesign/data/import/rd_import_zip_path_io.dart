import 'package:archive/archive_io.dart';

/// Apps: the ZIP is read from disk piece by piece instead of all at once
/// (a Drive download can be several hundred MB).
InputStreamBase? rdOpenZipPath(String path) => InputFileStream(path);
