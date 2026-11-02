// Photos, voice and push-to-talk on Public and #public: off by default, with a
// red warning to switch them on only in an emergency (MediaLockdown).

import 'package:flutter/material.dart';

import '../helpers/snack_bar_builder.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/media_lockdown.dart';

/// The "Photos and voice on Public" switch, with its red emergency warning.
/// In Settings > Messaging, and in the dialog a dimmed button opens.
class PublicMediaSwitch extends StatelessWidget {
  const PublicMediaSwitch({super.key, this.contentPadding});

  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final warn = theme.colorScheme.error;
    return ValueListenableBuilder<bool>(
      valueListenable: MediaLockdown.publicAllowed,
      builder: (context, allowed, _) => SwitchListTile(
        contentPadding: contentPadding,
        secondary: Icon(Icons.campaign_outlined, size: 24, color: warn),
        title: Text(l10n.publicMedia_title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.publicMedia_subtitle),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: warn),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.publicMedia_warning,
                    style: TextStyle(color: warn, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        activeThumbColor: warn,
        value: allowed,
        onChanged: (on) async {
          await MediaLockdown.setPublicAllowed(on);
          if (!context.mounted) return;
          showDismissibleSnackBar(
            context,
            content: Text(
              on ? l10n.publicMedia_turnedOn : l10n.publicMedia_turnedOff,
            ),
          );
        },
      ),
    );
  }
}

/// Explains why photos and voice are off on Public, with the switch.
Future<void> showPublicMediaOff(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.publicMedia_offTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.publicMedia_offBody),
          const SizedBox(height: 12),
          const PublicMediaSwitch(contentPadding: EdgeInsets.zero),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.common_ok),
      ),
    ],
  ),
);

/// A composer button for photos or voice: [child] as usual, or on Public and
/// #public while they're off there, the same [icon] dimmed, opening
/// [showPublicMediaOff]. [visible]: false when [child] would hide itself.
class PublicMediaGuard extends StatelessWidget {
  const PublicMediaGuard({
    super.key,
    required this.channel,
    required this.icon,
    required this.child,
    this.visible = true,
  });

  final Channel channel;
  final IconData icon;
  final Widget child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!MediaLockdown.isPublicMediaChannel(channel)) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: MediaLockdown.publicAllowed,
      builder: (context, allowed, _) {
        if (allowed) return child;
        if (!visible) return const SizedBox.shrink();
        return IconButton(
          icon: Icon(icon, color: Theme.of(context).disabledColor),
          tooltip: context.l10n.publicMedia_offTooltip,
          onPressed: () => showPublicMediaOff(context),
        );
      },
    );
  }
}
