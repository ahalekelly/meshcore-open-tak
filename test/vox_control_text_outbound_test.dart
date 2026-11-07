import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';

void main() {
  group('isVoxControlText', () {
    test('voice, photo and fetch texts are left alone', () {
      for (final t in [
        'VE3:1ps9wxb:1:4:2',
        'VM1:1ps9wxb:m:2:2 VOICE meet at the trailhead at noon',
        'VI1:1ps9wxb:k:i:4b IMAGE Look at this',
        'VR3:1ps9wxb:a:0123456789ab',
      ]) {
        expect(MeshCoreConnector.isVoxControlText(t), isTrue, reason: t);
      }
    });

    test('ordinary text is not', () {
      for (final t in ['hello there', 've3 is a codec', 'VE3 on its own']) {
        expect(MeshCoreConnector.isVoxControlText(t), isFalse, reason: t);
      }
    });
  });
}
