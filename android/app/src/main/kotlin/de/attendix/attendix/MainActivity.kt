package de.attendix.attendix

import com.ryanheise.audioservice.AudioServiceActivity

// NATIVE_MISC: AudioServiceActivity (a FlutterActivity) shares its engine with
// audio_service so lock-screen / notification media controls work.
class MainActivity : AudioServiceActivity()
