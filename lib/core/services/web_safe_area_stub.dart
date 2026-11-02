import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Non-web build: the platform reports the safe area itself.
final ValueListenable<EdgeInsets> webSafeAreaInsets =
    ValueNotifier(EdgeInsets.zero);

void initWebSafeArea() {}
