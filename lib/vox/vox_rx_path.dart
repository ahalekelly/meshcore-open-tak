// Which repeaters a channel media packet came through.
//
// A RESP_CODE_CHANNEL_DATA_RECV frame only says how many hops a packet took
// (and, from Wadamesh, the last hop). The companion firmware also pushes the
// raw packet as PUSH_CODE_LOG_RX_DATA (0x88) just before it processes it,
// and that raw packet carries the whole flood path: one path hash per
// repeater that relayed it, in order. This keeps the last few GRP_DATA raw
// packets and hands their path to the data frame that follows.

import 'dart:typed_data';

import '../connector/meshcore_protocol.dart'
    show advTypeRepeater, advTypeRoom, pushCodeLogRxData, payloadTypeGRPDATA;
import '../connector/raw_packet.dart'
    show decodePathByteLen, decodePathHashWidth;
import '../models/contact.dart';

/// The flood path of one received packet.
class VoxRxPath {
  /// Bytes per repeater hash (1-3).
  final int hashWidth;

  /// The path hashes in relay order, the first repeater first.
  final List<Uint8List> hops;

  const VoxRxPath(this.hashWidth, this.hops);

  int get hopCount => hops.length;

  Uint8List? get lastHop => hops.isEmpty ? null : hops.last;

  /// "a3>7f>12".
  String get hex => hops.map(_hexBytes).join('>');

  /// "1:a3>7f>12" (hash width, then the path), for saving.
  String toStorage() => '$hashWidth:$hex';

  /// Reads [toStorage]'s form back; null if it isn't one.
  static VoxRxPath? fromStorage(String s) {
    final colon = s.indexOf(':');
    if (colon < 1) return null;
    final width = int.tryParse(s.substring(0, colon));
    if (width == null || width < 1 || width > 3) return null;
    final body = s.substring(colon + 1);
    if (body.isEmpty) return VoxRxPath(width, const []);
    final hops = <Uint8List>[];
    for (final h in body.split('>')) {
      if (h.length != width * 2) return null;
      final bytes = Uint8List(width);
      for (var i = 0; i < width; i++) {
        final b = int.tryParse(h.substring(i * 2, i * 2 + 2), radix: 16);
        if (b == null) return null;
        bytes[i] = b;
      }
      hops.add(bytes);
    }
    return VoxRxPath(width, hops);
  }

  /// "a3 Capitol Hill > 7f ? > 12 Rattlesnake|Tiger": each hash with the
  /// repeater(s) it matches among [contacts] ("?" for none, "|" between
  /// several when the hash is too short to tell them apart).
  String describe(Iterable<Contact> contacts) {
    if (hops.isEmpty) return '(0 hop)';
    final relays = repeatersOf(contacts);
    return hops
        .map((h) {
          final names = repeaterNamesForHash(relays, h);
          return '${_hexBytes(h)} ${names.isEmpty ? '?' : names.join('|')}';
        })
        .join(' > ');
  }
}

/// The repeaters and room servers among [contacts]: the nodes that relay.
List<Contact> repeatersOf(Iterable<Contact> contacts) => contacts
    .where((c) => c.type == advTypeRepeater || c.type == advTypeRoom)
    .toList();

/// Names of the [relays] whose public key starts with path hash [hash]:
/// empty for an unknown repeater, several when the hash is too short to tell
/// them apart. A relay without a name shows as "?".
List<String> repeaterNamesForHash(List<Contact> relays, List<int> hash) => [
  for (final c in relays)
    if (_startsWith(c.publicKey, hash))
      c.name.trim().isEmpty ? '?' : c.name.trim(),
];

/// Hex of a path hash, lowercase ("a3", "a301").
String pathHashHex(List<int> hash) => _hexBytes(hash);

class _Seen {
  final DateTime at;
  final VoxRxPath path;
  bool claimed = false;
  _Seen(this.at, this.path);
}

/// Pairs raw-packet paths with the channel data frames that follow them.
class VoxRxPathTracker {
  /// How long a raw packet waits for its data frame. The firmware sends the
  /// two back to back, so this only has to cover transport jitter.
  final Duration window;

  VoxRxPathTracker({this.window = const Duration(seconds: 3)});

  final List<_Seen> _recent = [];

  /// Takes a PUSH_CODE_LOG_RX_DATA frame; keeps it if it is a flood GRP_DATA
  /// packet. Anything else is ignored.
  void addRxLog(Uint8List frame, [DateTime? now]) {
    final path = parseRxLogPath(frame);
    if (path == null) return;
    final t = now ?? DateTime.now();
    _prune(t);
    _recent.add(_Seen(t, path));
    if (_recent.length > 16) _recent.removeAt(0);
  }

  /// The path of the newest unclaimed packet with this hop count and hash
  /// width, seen within [window]; null when there is none (the firmware
  /// didn't send the raw packet, or it was a direct/raw-data packet).
  VoxRxPath? take({
    required int? hopCount,
    required int? hashWidth,
    DateTime? now,
  }) {
    if (hopCount == null) return null;
    _prune(now ?? DateTime.now());
    for (var i = _recent.length - 1; i >= 0; i--) {
      final s = _recent[i];
      if (s.claimed || s.path.hopCount != hopCount) continue;
      if (hashWidth != null && hopCount > 0 && s.path.hashWidth != hashWidth) {
        continue;
      }
      s.claimed = true;
      return s.path;
    }
    return null;
  }

  void _prune(DateTime now) {
    _recent.removeWhere((s) => now.difference(s.at) > window);
  }
}

/// The flood path of a PUSH_CODE_LOG_RX_DATA frame's packet, when it is a
/// flood-routed GRP_DATA packet; null otherwise.
///
/// Frame: [0x88][snr int8][rssi int8][header][transport codes 4B if route
/// type 0 or 3][path_len][path…][payload…].
VoxRxPath? parseRxLogPath(Uint8List frame) {
  if (frame.length < 5 || frame[0] != pushCodeLogRxData) return null;
  var i = 3;
  final header = frame[i++];
  final routeType = header & 0x03;
  final payloadType = (header >> 2) & 0x0F;
  if (payloadType != payloadTypeGRPDATA) return null;
  // Route types 0 and 1 are flood (0 with transport codes); 2 and 3 direct.
  if (routeType != 0 && routeType != 1) return null;
  if (routeType == 0) i += 4;
  if (frame.length <= i) return null;
  final pathLenRaw = frame[i++];
  if (pathLenRaw == 0xFF) return null;
  final width = decodePathHashWidth(pathLenRaw);
  if (width > 3) return null;
  final byteLen = decodePathByteLen(pathLenRaw);
  if (frame.length < i + byteLen + 1) return null;
  final hops = <Uint8List>[
    for (var at = i; at < i + byteLen; at += width)
      Uint8List.fromList(frame.sublist(at, at + width)),
  ];
  return VoxRxPath(width, hops);
}

bool _startsWith(Uint8List key, List<int> prefix) {
  if (key.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (key[i] != prefix[i]) return false;
  }
  return true;
}

String _hexBytes(List<int> b) =>
    b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
