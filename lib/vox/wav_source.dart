import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A source for the WAV bytes [wav] that every platform can play.
///
/// iOS and macOS play through AVPlayer, which can't play a BytesSource: it
/// fails with "AVPlayerItem.Status.failed on setSourceUrl" because the bytes
/// go to a file it can't tell the type of. There the WAV is written to a
/// temporary `.wav` file instead (one of a few names, reused in turn, so
/// they don't pile up). Elsewhere, the bytes as they are.
Future<Source> voxWavSource(Uint8List wav) async {
  if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
    return BytesSource(wav);
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/vox_play_${_next++ % _slots}.wav');
  await file.writeAsBytes(wav, flush: true);
  return DeviceFileSource(file.path);
}

// Enough names that a file is never rewritten while a player still has it.
const int _slots = 8;
int _next = 0;
