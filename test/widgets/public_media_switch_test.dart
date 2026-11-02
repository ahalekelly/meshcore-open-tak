import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/models/channel.dart';
import 'package:meshcore_open/services/media_lockdown.dart';
import 'package:meshcore_open/widgets/public_media_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _public = Channel.fromHex(0, 'Public', Channel.publicChannelPsk);
final _hashPublic = Channel(index: 1, name: '#public', psk: Uint8List(16));
final _team = Channel(index: 2, name: 'Team', psk: Uint8List(16)..[0] = 7);

Future<void> _pumpGuard(WidgetTester tester, Channel channel) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PublicMediaGuard(
            channel: channel,
            icon: Icons.mic_none,
            child: const Text('real mic'),
          ),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MediaLockdown.load();
  });

  group('Public and #public', () {
    test('are the channels everyone shares', () {
      expect(MediaLockdown.isPublicMediaChannel(_public), isTrue);
      expect(MediaLockdown.isPublicMediaChannel(_hashPublic), isTrue);
      expect(
        MediaLockdown.isPublicMediaChannel(
          Channel(index: 3, name: ' #Public ', psk: Uint8List(16)),
        ),
        isTrue,
      );
      expect(MediaLockdown.isPublicMediaChannel(_team), isFalse);
      expect(
        MediaLockdown.isPublicMediaChannel(
          Channel(index: 4, name: '#publicsafety', psk: Uint8List(16)),
        ),
        isFalse,
      );
    });

    test('refuse photos and voice by default', () {
      expect(MediaLockdown.publicAllowed.value, isFalse);
      expect(MediaLockdown.blocksChannel(_public), isTrue);
      expect(MediaLockdown.blocksChannel(_hashPublic), isTrue);
      expect(MediaLockdown.blocksChannel(_team), isFalse);
    });

    test('the switch is saved and loaded again', () async {
      await MediaLockdown.setPublicAllowed(true);
      expect(MediaLockdown.blocksChannel(_public), isFalse);
      MediaLockdown.publicAllowed.value = false;
      await MediaLockdown.load();
      expect(MediaLockdown.publicAllowed.value, isTrue);
      await MediaLockdown.setPublicAllowed(false);
      expect(MediaLockdown.blocksChannel(_public), isTrue);
    });

    test('the refusal says how to switch it on', () {
      expect(
        const PublicMediaBlockedException().toString(),
        MediaLockdown.publicBlockedMessage,
      );
      expect(const PublicMediaBlockedException(), isA<MediaBlockedException>());
    });
  });

  group('PublicMediaGuard', () {
    testWidgets('other channels get the real button', (tester) async {
      await _pumpGuard(tester, _team);
      expect(find.text('real mic'), findsOneWidget);
    });

    testWidgets('Public gets a dimmed button that explains, with the switch '
        'and its red warning', (tester) async {
      await _pumpGuard(tester, _public);
      expect(find.text('real mic'), findsNothing);
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();
      expect(find.text('Photos and voice are off here'), findsOneWidget);
      expect(find.text('Only switch this on in an emergency.'), findsOneWidget);
      final warning = tester.widget<Text>(
        find.text('Only switch this on in an emergency.'),
      );
      final scheme = Theme.of(tester.element(find.byType(Dialog))).colorScheme;
      expect(warning.style?.color, scheme.error);

      // Switching it on in the dialog brings the real button back.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(MediaLockdown.publicAllowed.value, isTrue);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('real mic'), findsOneWidget);
    });
  });
}
