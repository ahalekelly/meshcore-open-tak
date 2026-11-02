import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/channel.dart';
import 'package:meshcore_open/models/channel_message.dart';
import 'package:meshcore_open/team/transit_watch.dart';
import 'package:meshcore_open/team/watch_feed.dart';

final _ch = Channel(index: 4, name: '#transit', psk: Uint8List(16));
final _sent = DateTime(2026, 10, 27, 8, 10);

WatchItem _item(String text, {DateTime? at}) => parseWatchMessage(
  _ch,
  ChannelMessage(
    senderName: 'SeaBot',
    text: text,
    timestamp: at ?? _sent,
    isOutgoing: false,
  ),
);

void main() {
  test('a stop reply: arrivals, live or timetable, offline, position', () {
    final r = parseTransit(
      '🚏 3rd Ave & Pike St, Bay 2\n'
      '🚌 11 - 5 mins 🕒\n'
      '🚍 G Line - now\n'
      '⛴️ Seattle-Bainbridge - 21:05 🕒\n'
      '📴 offline: schedule times only\n'
      'also: ct 1120\n'
      '📍 47.60000,-122.30000 · 1120',
    )!;
    expect(r.kind, TransitKind.stop);
    expect(r.title, '3rd Ave & Pike St, Bay 2');
    expect(r.agency, isNull);
    expect(r.stopRef, '1120');
    expect(r.lat, closeTo(47.6, 1e-9));
    expect(r.lon, closeTo(-122.3, 1e-9));
    expect(r.offline, isTrue);
    expect(r.also, ['ct 1120']);
    expect(r.arrivals.map((a) => a.route), [
      '11',
      'G Line',
      'Seattle-Bainbridge',
    ]);
    expect(r.arrivals[0].mode, TransitMode.bus);
    expect(r.arrivals[0].minutes, 5);
    expect(r.arrivals[0].scheduled, isTrue);
    expect(r.arrivals[1].mode, TransitMode.rapid);
    expect(r.arrivals[1].minutes, 0);
    expect(r.arrivals[1].scheduled, isFalse);
    expect(r.arrivals[2].mode, TransitMode.ferry);
    expect(r.arrivals[2].at(_sent), DateTime(2026, 10, 27, 21, 5));
    expect(r.status, 'BUS');
  });

  test('countdowns run from when the reply was sent', () {
    final a = parseTransit('🚏 Stop\n🚌 11 - 5 mins')!.arrivals.single;
    final at = a.at(_sent)!;
    expect(transitCountdown(at, _sent), '5 min');
    expect(
      transitCountdown(at, _sent.add(const Duration(minutes: 3))),
      '2 min',
    );
    expect(transitCountdown(at, _sent.add(const Duration(minutes: 5))), 'due');
    expect(transitCountdown(at, _sent.add(const Duration(minutes: 9))), 'gone');
  });

  test("another agency's stop and a route reply", () {
    final r = parseTransit(
      '🚌 201 @ Everett Station Bay 3 · CT\n5 mins 🕒\n17 mins 🕒\n'
      '📍 47.97500,-122.19700 · ct 1120',
    )!;
    expect(r.kind, TransitKind.route);
    expect(r.route, '201');
    expect(r.title, 'Everett Station Bay 3');
    expect(r.agency, 'ct');
    expect(transitAgencyName(r.agency), 'Community Transit');
    expect(r.stopRef, 'ct 1120');
    expect(r.arrivals.map((a) => a.minutes), [5, 17]);
    expect(r.headline, '201 @ Everett Station Bay 3');
  });

  test('alerts replies', () {
    final r = parseTransit(
      '🚏 3rd Ave & Pike St, Bay 2\n⚠️ Route 11 detour on Pine St\n'
      '📍 47.60000,-122.30000 · 1120',
    )!;
    expect(r.kind, TransitKind.alerts);
    expect(r.alerts, ['Route 11 detour on Pine St']);
    expect(r.warns, isTrue);
    expect(parseTransit('🚏 Stop\n✅ No alerts.')!.alertsClear, isTrue);
    expect(
      parseTransit(
        "🚏 Stop\n📴 Can't reach live alerts right now.",
      )!.alertsUnknown,
      isTrue,
    );
  });

  test('stop numbers with letters and underscores (Sound Transit)', () {
    final r = parseTransit(
      '🚏 Everett Station · ST\n🚆 N Line - 12 mins\n'
      '📍 47.97500,-122.19700 · st S_EV',
    )!;
    expect(r.stopRef, 'st S_EV');
    expect(r.hasPosition, isTrue);
    final s = parseTransit(
      '🔎 everett station:\n🚏 st S_EV Everett Station → N Line',
    )!;
    expect(s.stops.single.ref, 'st S_EV');
  });

  test('a trip plan', () {
    final r = parseTransit(
      '🧭 Arrive 8:25 · 45 min · 1 transfer · timetable\n'
      '🚌 11 7:50 11040 → 3rd Ave & Pike St, Bay 2 8:00\n'
      '🚶 1 min to 1121\n'
      '🚌 49 8:15 1121 → Broadway & E Madison St 8:25\n'
      '📍 47.61000,-122.32000 · 11040',
    )!;
    expect(r.kind, TransitKind.plan);
    expect(r.planArrive, '8:25');
    expect(r.planMinutes, 45);
    expect(r.planTransfers, 1);
    expect(r.legs.length, 3);
    expect(r.legs[0].route, '11');
    expect(r.legs[0].board, '11040');
    expect(r.legs[0].to, '3rd Ave & Pike St, Bay 2');
    expect(r.legs[1].walk, isTrue);
    expect(r.legs[1].to, '1121');
    expect(r.legs[2].arrive, '8:25');
    expect(transitPlanTime('8:25', _sent), DateTime(2026, 10, 27, 8, 25));
    expect(
      transitPlanTime('1:05', DateTime(2026, 10, 27, 23, 50)),
      DateTime(2026, 10, 28, 1, 5),
    );
  });

  test('stops found', () {
    final r = parseTransit(
      '🔎 Near Seattle Center:\n'
      '🚏 11050 Broadway & E Madison St · 0.6 mi → 49\n'
      '🚏 ct 1120 Everett Station Bay 3 → 201, Swift Blue',
    )!;
    expect(r.kind, TransitKind.search);
    expect(r.stops.map((s) => s.ref), ['11050', 'ct 1120']);
    expect(r.stops[0].distance, '0.6 mi');
    expect(r.stops[1].routes, ['201', 'Swift Blue']);
  });

  test('alert posts only on a transit channel', () {
    final r = parseTransit('⚠️ CT 201: Detour on Hwy 99', alertPosts: true)!;
    expect(r.kind, TransitKind.alert);
    expect(r.title, 'CT 201');
    expect(parseTransit('⚠️ CT 201: Detour on Hwy 99'), isNull);
    // a long one in two messages is joined back together
    final head = parseTransit(
      '⚠️ 11: No service on 3rd Ave … [1/2 k3]',
      alertPosts: true,
    )!;
    expect(head.partTag, 'k3');
    expect(head.partIndex, 1);
    final rest = parseTransit(
      '… due to police activity [2/2 k3]',
      alertPosts: true,
    )!;
    expect(rest.hasHeader, isFalse);
    expect(rest.partTag, 'k3');
    expect(rest.partIndex, 2);
    expect(head.merge(rest).alerts, [
      'No service on 3rd Ave due to police activity',
    ]);
    expect(parseTransit('… due to police activity'), isNull);
  });

  test("other channels' messages aren't transit", () {
    expect(parseTransit('🔴 CRITICAL\n10-03 11:30\n🧊 @Auburn'), isNull);
    expect(parseTransit('meet at the bus stop - now'), isNull);
    expect(parseTransit('Drone at 47.30731, -122.22850 low and slow'), isNull);
  });

  test('the rest of a split reply joins its first part', () {
    final head = parseTransit('🚏 3rd Ave & Pike St, Bay 2\n🚌 11 - 5 mins')!;
    final part = parseTransit(
      '🚍 G Line - 18 mins\n📍 47.60000,-122.30000 · 1120',
    )!;
    expect(part.hasHeader, isFalse);
    final r = head.merge(part);
    expect(r.kind, TransitKind.stop);
    expect(r.arrivals.length, 2);
    expect(r.stopRef, '1120');
    expect(r.hasPosition, isTrue);
  });

  test('a Watch item carries the transit card and the stop on the map', () {
    final it = _item(
      '🚏 3rd Ave & Pike St, Bay 2\n🚌 11 - 5 mins\n'
      '📍 47.60000,-122.30000 · 1120',
    );
    expect(it.transit, isNotNull);
    expect(it.statusWord, 'BUS');
    expect(it.place, '3rd Ave & Pike St, Bay 2');
    expect(it.level, WatchLevel.other);
    expect(it.hasPosition, isTrue);
  });

  test('a long alert post is joined by its tag, in either order', () {
    final head = _item(
      '⚠️ 331: Route 331 trip to UW Bothell from Shoreline is not … [1/2 k3]',
    );
    final rest = _item(
      '… operating today. [2/2 k3]',
      at: _sent.add(const Duration(seconds: 8)),
    );
    expect(rest.statusWord, 'ALERT');
    const whole = [
      'Route 331 trip to UW Bothell from Shoreline is not operating today.',
    ];
    expect(joinTransitParts(head, rest)!.transit!.alerts, whole);
    // the second part heard first
    final swapped = joinTransitParts(rest, head)!;
    expect(swapped.transit!.alerts, whole);
    expect(swapped.statusWord, 'ALERT');
    expect(swapped.place, '331');
    // never by guess: another alert's half, an untagged half, or a bus reply
    final other = _item('… running late. [2/2 x9]');
    expect(joinTransitParts(head, other), isNull);
    expect(joinTransitParts(head, _item('… operating today.')), isNull);
    final bus = _item('🚏 3rd Ave & Pike St, Bay 2\n🚌 11 - 5 mins');
    expect(joinTransitParts(bus, rest), isNull);
    expect(joinTransitParts(rest, bus), isNull);
    expect(joinTransitParts(head, _item('🚍 G Line - 18 mins')), isNull);
    // two whole replies stay apart
    expect(joinTransitParts(head, head), isNull);
  });
}
