import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/vox/voice_service.dart';

void main() {
  tearDown(() => VoxReceivedVia.connectedRadioHasRadio2 = null);

  test('a tagged frame says where it came from', () {
    VoxReceivedVia.connectedRadioHasRadio2 = true;
    expect(VoxReceivedVia.forReceived(1), VoxReceivedVia.mainMesh);
    expect(VoxReceivedVia.forReceived(2), VoxReceivedVia.mediaMesh);
    expect(VoxReceivedVia.forReceived(3), VoxReceivedVia.both);
  });

  test('untagged: main mesh only when the radio has no radio2', () {
    VoxReceivedVia.connectedRadioHasRadio2 = false;
    expect(VoxReceivedVia.forReceived(0), VoxReceivedVia.mainMesh);
    expect(VoxReceivedVia.forReceived(null), VoxReceivedVia.mainMesh);
  });

  test('untagged from a radio with radio2, or one not yet asked: nothing', () {
    VoxReceivedVia.connectedRadioHasRadio2 = true;
    expect(VoxReceivedVia.forReceived(0), isNull);
    VoxReceivedVia.connectedRadioHasRadio2 = null;
    expect(VoxReceivedVia.forReceived(0), isNull);
    expect(VoxReceivedVia.forReceived(null), isNull);
  });
}
