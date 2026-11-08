import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/vox/voice_wire.dart';

void main() {
  test('a copy id gives back its clip and length', () {
    const mimi = '1a2b3c4d';
    for (final s in [1, 2, 7, 20, voxCodec2CopyMaxSeconds]) {
      final copy = voxCodec2CopySid(mimi, s);
      expect(copy, isNot(mimi));
      expect(voxCodec2CopySeconds(copy, mimi), s);
    }
    // Zero rounds up to one second.
    expect(voxCodec2CopySeconds(voxCodec2CopySid(mimi, 0), mimi), 1);
  });

  test('other ids are not copies', () {
    const mimi = '1a2b3c4d';
    expect(voxCodec2CopySeconds(mimi, mimi), isNull);
    expect(voxCodec2CopySeconds('deadbeef', mimi), isNull);
    // A parity session (vox_fec.dart) is not a copy.
    final parity = voxSessionIdFromInt(0x1a2b3c4d ^ 0xFEC0FEC0);
    expect(voxCodec2CopySeconds(parity, mimi), isNull);
  });

  test('packet count matches packetizing a copy that long', () {
    for (final s in [1, 2, 5, 10, 20, 60, voxCodec2CopyMaxSeconds]) {
      final bytes = s * voxCodec2CopyMode.bytesPerSecond;
      final packets = voxPacketize(
        voxCodec2CopySid('00000001', s),
        Uint8List(bytes),
        voxCodec2CopyMode,
      );
      expect(packets.length, voxCodec2CopyPackets(s), reason: '${s}s');
    }
    expect(
      voxCodec2CopyPackets(voxCodec2CopyMaxSeconds),
      lessThanOrEqualTo(voxMaxPackets),
    );
  });
}
