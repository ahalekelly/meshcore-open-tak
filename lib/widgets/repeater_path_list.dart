import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../theme/mesh_theme.dart';
import '../vox/vox_rx_path.dart';

/// Splits a flood path into its repeater hashes, [hashWidth] bytes each, in
/// relay order. A trailing partial hash is dropped.
List<List<int>> splitPathHashes(List<int> path, int hashWidth) {
  final w = hashWidth.clamp(1, 3).toInt();
  return [
    for (var at = 0; at + w <= path.length; at += w) path.sublist(at, at + w),
  ];
}

/// The repeaters a packet came through, one per line, numbered in relay
/// order: 1 is the first repeater after the sender, the last is the one
/// that handed it to this radio. Each line shows the repeater's name (from
/// the contact list; "Unknown repeater" when no known repeater has that
/// hash, several names when the hash is too short to tell them apart) and
/// its path hash.
class RepeaterPathList extends StatelessWidget {
  /// The path hashes, in relay order.
  final List<List<int>> hops;

  /// A line above the list ("Voice/photo packets · 3 hops"), or null.
  final String? label;

  final Color color;
  final double textScale;

  const RepeaterPathList({
    super.key,
    required this.hops,
    required this.color,
    this.label,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (hops.isEmpty && label == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final relays = repeatersOf(context.read<MeshCoreConnector>().contacts);
    final text = TextStyle(color: color, fontSize: 12 * textScale);
    final mono = MeshTheme.mono(fontSize: 11 * textScale, color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) Text(label!, style: text),
          for (var i = 0; i < hops.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 18 * textScale,
                  child: Text('${i + 1}', style: mono),
                ),
                Flexible(
                  child: Text(
                    _names(relays, hops[i], l10n.chat_repeaterPathUnknown),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text,
                  ),
                ),
                const SizedBox(width: 6),
                Text(pathHashHex(hops[i]), style: mono),
              ],
            ),
        ],
      ),
    );
  }

  static String _names(List<Contact> relays, List<int> hash, String unknown) {
    final names = repeaterNamesForHash(relays, hash);
    return names.isEmpty ? unknown : names.join(' / ');
  }
}
