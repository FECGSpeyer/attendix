import 'dart:io' show Platform;

/// NATIVE_MISC: host OS is iOS or Android (the installed app).
bool get hostIsNativeMobile => Platform.isIOS || Platform.isAndroid;
