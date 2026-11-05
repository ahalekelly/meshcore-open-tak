import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/models/contact.dart';
import 'package:meshcore_open/models/app_settings.dart';
import 'package:meshcore_open/vox/vox_rx_path.dart';
import 'package:meshcore_open/widgets/repeater_path_list.dart';

/// A PUSH_CODE_LOG_RX_DATA frame for a packet of [payloadType] with [path].
Uint8List rxLog({
  int payloadType = payloadTypeGRPDATA,
  int routeType = 1,
  List<int> path = const [],
  int width = 1,
}) {
  final header = (payloadType << 2) | routeType;
  final pathLen = path.isEmpty
      ? 0
      : ((width - 1) << 6) | (path.length ~/ width);
  return Uint8List.fromList([
    pushCodeLogRxData,
    40, // snr
    0xA6, // rssi
    header,
    if (routeType == 0) ...[1, 2, 3, 4],
    pathLen,
    ...path,
    0x5A, 1, 2, 3, 4, 5, // channel hash + MAC + ciphertext
  ]);
}

Contact repeater(String name, List<int> keyStart) => Contact(
  publicKey: Uint8List.fromList([
    ...keyStart,
    ...List.filled(32 - keyStart.length, 0),
  ]),
  name: name,
  type: advTypeRepeater,
  pathLength: -1,
  path: Uint8List(0),
  lastSeen: DateTime(2026),
);

void main() {
  test('parses a flood GRP_DATA path in relay order', () {
    final p = parseRxLogPath(rxLog(path: [0xa3, 0x7f, 0x12]))!;
    expect(p.hopCount, 3);
    expect(p.hex, 'a3>7f>12');
    expect(p.lastHop, [0x12]);
  });

  test('handles transport codes and 2-byte hashes', () {
    final p = parseRxLogPath(
      rxLog(routeType: 0, width: 2, path: [0xa3, 0x01, 0x7f, 0x02]),
    )!;
    expect(p.hashWidth, 2);
    expect(p.hex, 'a301>7f02');
  });

  test('ignores other packet types and direct routes', () {
    expect(parseRxLogPath(rxLog(payloadType: payloadTypeGRPTXT)), isNull);
    expect(parseRxLogPath(rxLog(routeType: 2, path: [1])), isNull);
  });

  test('pairs a data frame with the newest matching raw packet', () {
    final t = DateTime(2026, 11, 4, 23);
    final tracker = VoxRxPathTracker()
      ..addRxLog(rxLog(path: [0x01, 0x02]), t)
      ..addRxLog(rxLog(path: [0x0a]), t)
      ..addRxLog(rxLog(path: [0x03, 0x04]), t);
    final got = tracker.take(hopCount: 2, hashWidth: 1, now: t)!;
    expect(got.hex, '03>04');
    // Each raw packet is claimed once.
    expect(tracker.take(hopCount: 2, hashWidth: 1, now: t)!.hex, '01>02');
    expect(tracker.take(hopCount: 2, hashWidth: 1, now: t), isNull);
    // Too old.
    expect(
      tracker.take(
        hopCount: 1,
        hashWidth: 1,
        now: t.add(const Duration(seconds: 10)),
      ),
      isNull,
    );
  });

  test('names repeaters, flagging unknown and colliding hashes', () {
    final p = parseRxLogPath(rxLog(path: [0xa3, 0x7f, 0x12]))!;
    final names = p.describe([
      repeater('Capitol Hill', [0xa3, 0x11]),
      repeater('Tiger', [0x12, 0x01]),
      repeater('Rattlesnake', [0x12, 0x02]),
    ]);
    expect(names, 'a3 Capitol Hill > 7f ? > 12 Tiger|Rattlesnake');
  });

  test('a saved path reads back in the same order', () {
    final p = parseRxLogPath(rxLog(width: 2, path: [0xa3, 1, 0x7f, 2]))!;
    final back = VoxRxPath.fromStorage(p.toStorage())!;
    expect(back.hashWidth, 2);
    expect(back.hex, 'a301>7f02');
    expect(VoxRxPath.fromStorage('1:')!.hopCount, 0);
    expect(VoxRxPath.fromStorage('nonsense'), isNull);
    expect(VoxRxPath.fromStorage('1:a3>7'), isNull);
  });

  test('splits a message path into hashes, first relay first', () {
    expect(splitPathHashes([0xa3, 0x7f, 0x12], 1), [
      [0xa3],
      [0x7f],
      [0x12],
    ]);
    expect(splitPathHashes([1, 2, 3, 4, 5], 2), [
      [1, 2],
      [3, 4],
    ]);
  });

  test('the repeater list setting is off by default', () {
    expect(AppSettings().showRepeaterPath, isFalse);
    expect(AppSettings.fromJson(const {}).showRepeaterPath, isFalse);
    final on = AppSettings().copyWith(showRepeaterPath: true);
    expect(AppSettings.fromJson(on.toJson()).showRepeaterPath, isTrue);
  });
}
