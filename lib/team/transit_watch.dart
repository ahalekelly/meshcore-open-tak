// MeshCore Open TAK - transit cards for the Watch tab.
//
// BusBot (github.com/jade-on-mesh/BusBot-2.0) answers transit questions in a
// channel such as #transit with short plain-text replies, sized for the mesh:
//
//   🚏 3rd Ave & Pike St, Bay 2
//   🚌 11 - 5 mins 🕒
//   🚍 G Line - now
//   📴 offline: schedule times only
//   also: ct 1120
//   📍 47.60000,-122.30000 · 1120
//
// When that channel is watched, this reads them back into a structured
// report, so the Watch tab can show a full card: the stop's number and
// agency, each route with its mode, arrival clock times with countdowns that
// keep ticking, live versus timetable, alerts, trip plans as steps, and the
// stop on the map. A reply split over several messages is joined back
// together ([TransitReport.merge]). Wadamesh TAK reads the same format
// (src/ui-touch/TransitFeed.h).
//
// Pure Dart: no Flutter, host-tested in test/transit_watch_test.dart.

/// What a BusBot reply is about.
enum TransitKind {
  /// "bus [stop]": next arrival per route.
  stop,

  /// "bus [stop] [route]": the next few of one route.
  route,

  /// "alerts [stop]".
  alerts,

  /// "go A to B": a trip plan.
  plan,

  /// "stops [place]", "near": stops found.
  search,

  /// A service alert BusBot posts on a quiet channel: "⚠ CT 201: …".
  alert,

  /// A part of a split reply with no header of its own.
  part,
}

/// Transport modes, from the emoji BusBot puts before a route.
enum TransitMode {
  bus('🚌', 'Bus'),
  rapid('🚍', 'RapidRide'),
  rail('🚋', 'Light rail / streetcar'),
  train('🚆', 'Train'),
  ferry('⛴\uFE0F', 'Ferry');

  const TransitMode(this.emoji, this.label);
  final String emoji;
  final String label;

  static TransitMode? fromEmoji(String? e) {
    if (e == null) return null;
    final bare = e.replaceAll('\uFE0F', '');
    for (final m in values) {
      if (m.emoji.replaceAll('\uFE0F', '') == bare) return m;
    }
    return null;
  }
}

/// Agencies BusBot covers, by the code it writes after a stop (" · CT") or
/// before a stop number ("ct 1120"). A stop with no code is the bot's
/// default agency, King County Metro unless its operator changed feeds.json.
const Map<String, String> transitAgencies = {
  'kcm': 'King County Metro',
  'st': 'Sound Transit',
  'ct': 'Community Transit',
  'pt': 'Pierce Transit',
  'et': 'Everett Transit',
  'it': 'Intercity Transit',
  'kt': 'Kitsap Transit',
  'wsf': 'Washington State Ferries',
  'mono': 'Seattle Center Monorail',
};

const String transitDefaultAgency = 'kcm';

String transitAgencyName(String? code) =>
    transitAgencies[(code ?? transitDefaultAgency).toLowerCase()] ??
    code!.toUpperCase();

/// One upcoming departure.
class TransitArrival {
  final TransitMode? mode;
  final String route;

  /// Minutes after the reply was sent ("now" is 0), when written that way.
  final int? minutes;

  /// "21:05" when it is more than an hour out.
  final int? hour, minute;

  /// From the timetable (🕒 or "(s)"), not live tracking.
  final bool scheduled;

  const TransitArrival({
    this.mode,
    required this.route,
    this.minutes,
    this.hour,
    this.minute,
    this.scheduled = false,
  });

  /// When it arrives, for a reply sent at [sent].
  DateTime? at(DateTime sent) {
    if (minutes != null) return sent.add(Duration(minutes: minutes!));
    if (hour == null || minute == null) return null;
    var t = DateTime(sent.year, sent.month, sent.day, hour!, minute!);
    if (t.isBefore(sent.subtract(const Duration(hours: 1)))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}

/// One step of a trip plan.
class TransitLeg {
  /// null for a walk.
  final TransitMode? mode;
  final bool walk;
  final String? route;

  /// "7:50" as written (12-hour clock, no am/pm).
  final String? depart, arrive;

  /// Stop number boarded at, when the plan names it ("11040", "ct 1120").
  final String? board;

  /// Where the ride gets off, or where a walk goes ("1121", "destination").
  final String to;
  final int? walkMinutes;

  const TransitLeg({
    this.mode,
    this.walk = false,
    this.route,
    this.depart,
    this.arrive,
    this.board,
    required this.to,
    this.walkMinutes,
  });
}

/// A stop in a search reply.
class TransitStopHit {
  final String ref; // "1120", "ct 1120"
  final String name;
  final String? distance; // "350 ft", "1.2 mi"
  final List<String> routes;
  const TransitStopHit({
    required this.ref,
    required this.name,
    this.distance,
    this.routes = const [],
  });
}

class TransitReport {
  final TransitKind kind;

  /// The stop (or the search, or "Trip") the reply is about.
  final String? title;

  /// Agency code from the header (" · CT"), null for the default agency.
  final String? agency;

  /// The route a "bus [stop] [route]" reply is about, and its mode.
  final String? route;
  final TransitMode? routeMode;

  /// From the position line: the stop's number and where it is.
  final String? stopRef;
  final double? lat, lon;

  final List<TransitArrival> arrivals;
  final List<String> alerts;

  /// Alerts were checked and there are none.
  final bool alertsClear;

  /// Live alerts couldn't be checked.
  final bool alertsUnknown;

  /// BusBot couldn't reach live tracking: times are from the timetable.
  final bool offline;

  /// No more trips today at this stop.
  final bool noTrips;

  /// Other agencies' stops with the same number ("ct 1120").
  final List<String> also;

  /// A trip plan: "Arrive 8:25 · 45 min · 1 transfer · timetable" parts.
  final String? planArrive;
  final int? planMinutes;
  final int planTransfers;
  final List<TransitLeg> legs;

  final List<TransitStopHit> stops;

  /// Lines this doesn't model, as written.
  final List<String> notes;

  /// The rest of an alert post that the bot sent as two messages
  /// ("⚠️ … text …", then "… the rest").
  final String? continues;

  /// A long alert post's halves end with the same tag, "[1/2 k3]" and
  /// "[2/2 k3]": [partTag] "k3", [partIndex] 1 or 2. Only halves with the
  /// same tag are joined.
  final String? partTag;
  final int? partIndex;

  const TransitReport({
    required this.kind,
    this.title,
    this.agency,
    this.route,
    this.routeMode,
    this.stopRef,
    this.lat,
    this.lon,
    this.arrivals = const [],
    this.alerts = const [],
    this.alertsClear = false,
    this.alertsUnknown = false,
    this.offline = false,
    this.noTrips = false,
    this.also = const [],
    this.planArrive,
    this.planMinutes,
    this.planTransfers = 0,
    this.legs = const [],
    this.stops = const [],
    this.notes = const [],
    this.continues,
    this.partTag,
    this.partIndex,
  });

  bool get hasHeader => kind != TransitKind.part;
  bool get hasPosition => lat != null && lon != null;

  /// The Watch card's status word.
  String get status => switch (kind) {
    TransitKind.part when continues != null => 'ALERT',
    TransitKind.plan => 'TRIP',
    TransitKind.search => 'STOPS',
    TransitKind.alerts => 'ALERTS',
    TransitKind.alert => 'ALERT',
    _ => switch (routeMode ?? (arrivals.isEmpty ? null : arrivals.first.mode)) {
      TransitMode.ferry => 'FERRY',
      TransitMode.train => 'TRAIN',
      TransitMode.rail => 'RAIL',
      _ => 'BUS',
    },
  };

  /// Worth a warning colour: alerts to read.
  bool get warns => kind == TransitKind.alert || alerts.isNotEmpty;

  /// The headline: the stop, the search, or the trip's arrival.
  String get headline {
    if (kind == TransitKind.plan) {
      return [
        if (planArrive != null) 'Arrive $planArrive',
        if (legs.isNotEmpty && legs.last.to != 'destination') legs.last.to,
      ].join(' · ');
    }
    if (kind == TransitKind.alert) return title ?? 'Service alert';
    final r = route == null ? '' : '$route @ ';
    return '$r${title ?? stopRef ?? 'Transit'}';
  }

  /// [part]'s lines added to this report (a reply split over messages).
  TransitReport merge(TransitReport part) => TransitReport(
    kind: kind == TransitKind.part
        ? part.kind
        : kind == TransitKind.stop &&
              arrivals.isEmpty &&
              part.arrivals.isEmpty &&
              (part.alerts.isNotEmpty || part.alertsClear || part.alertsUnknown)
        ? TransitKind.alerts
        : kind,
    title: title ?? part.title,
    agency: agency ?? part.agency,
    route: route ?? part.route,
    routeMode: routeMode ?? part.routeMode,
    stopRef: stopRef ?? part.stopRef,
    lat: lat ?? part.lat,
    lon: lon ?? part.lon,
    arrivals: [...arrivals, ...part.arrivals],
    partTag: partTag ?? part.partTag,
    alerts: part.continues != null && alerts.isNotEmpty
        ? [
            ...alerts.sublist(0, alerts.length - 1),
            '${alerts.last.replaceFirst(RegExp(r'\s*…$'), '')} '
                '${part.continues}',
          ]
        : [...alerts, ...part.alerts],
    alertsClear: alertsClear || part.alertsClear,
    alertsUnknown: alertsUnknown || part.alertsUnknown,
    offline: offline || part.offline,
    noTrips: noTrips || part.noTrips,
    also: [...also, ...part.also],
    planArrive: planArrive ?? part.planArrive,
    planMinutes: planMinutes ?? part.planMinutes,
    planTransfers: planTransfers > 0 ? planTransfers : part.planTransfers,
    legs: [...legs, ...part.legs],
    stops: [...stops, ...part.stops],
    notes: [...notes, ...part.notes],
  );
}

// ---------------------------------------------------------------- parsing

const _modeAlt = r'🚌|🚍|🚋|🚆|⛴\uFE0F?';
final _stopHeadRe = RegExp(r'^🚏\s+(.+?)(?:\s+·\s+([A-Z]{2,4}))?$');
final _routeHeadRe = RegExp(
  '^($_modeAlt)\\s+(.+?)\\s+@\\s+(.+?)(?:\\s+·\\s+([A-Z]{2,4}))?\$',
);
final _planHeadRe = RegExp(
  r'^🧭\s+Arrive\s+(\d{1,2}:\d{2})\s+·\s+(-?\d+)\s+min'
  r'(?:\s+·\s+(\d+)\s+transfers?)?\s+·\s+timetable$',
);
final _searchHeadRe = RegExp(r'^(?:🔎|📍)\s+(.+):$');
final _partTagRe = RegExp(r'\s*\[([12])/2 ([0-9a-z]{2})\]$');
final _alertPostRe = RegExp(r'^⚠\uFE0F?\s+(?:([^:\n]{1,40}):\s+)?(.+)$');
const _timeAlt = r'now|\d+\s+mins?|\d{1,2}:\d{2}';
final _arrivalRe = RegExp(
  '^(?:($_modeAlt)\\s+)?(.+?)\\s+-\\s+($_timeAlt)(\\s+🕒|\\s+\\(s\\))?\$',
);
final _timeOnlyRe = RegExp('^($_timeAlt)(\\s+🕒|\\s+\\(s\\))?\$');
final _geoRe = RegExp(
  r'^(?:📍\s+)?(-?\d{1,2}\.\d{3,}),(-?\d{1,3}\.\d{3,})\s+·\s+((?:[a-z]{2,4}\s+)?[\w.-]+)$',
);
final _rideRe = RegExp(
  '^($_modeAlt)\\s+(.+?)\\s+(\\d{1,2}:\\d{2})(?:\\s+((?:[a-z]{2,4}\\s+)?[A-Za-z0-9][\\w.-]*))?'
  '\\s+→\\s+(.+?)\\s+(\\d{1,2}:\\d{2})\$',
);
final _walkRe = RegExp(r'^🚶\s+(\d+)\s+min\s+to\s+(.+)$');
final _hitRe = RegExp(
  r'^🚏\s+((?:[a-z]{2,4}\s+)?[\w.-]*\d[\w.-]*|(?:[a-z]{2,4}\s+)[\w.-]+)\s+(.+?)(?:\s+·\s+([\d.]+\s+(?:ft|mi)))?\s+→\s+(.+)$',
);

TransitArrival _arrival(String? emoji, String route, String time, String? s) {
  int? minutes, hour, minute;
  if (time == 'now') {
    minutes = 0;
  } else if (time.contains(':')) {
    final p = time.split(':');
    hour = int.tryParse(p[0]);
    minute = int.tryParse(p[1]);
  } else {
    minutes = int.tryParse(time.split(RegExp(r'\s+')).first);
  }
  return TransitArrival(
    mode: TransitMode.fromEmoji(emoji),
    route: route,
    minutes: minutes,
    hour: hour,
    minute: minute,
    scheduled: s != null,
  );
}

/// [text] read as a BusBot reply, or null when it isn't one.
///
/// A message counts when its first line is one of BusBot's headers (🚏 stop,
/// "🚌 11 @ stop", 🧭 trip, 🔎 search, ⚠ "CT 201: …"), or, for the rest of a
/// split reply, when every line is one BusBot writes and one of them is
/// unmistakable (a route's arrival, the position line, "also:").
///
/// [alertPosts]: a lone "⚠ …" line is the bot's alert post. Only for a
/// transit channel, where people don't post warnings of their own.
TransitReport? parseTransit(String text, {bool alertPosts = false}) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (lines.isEmpty) return null;

  var kind = TransitKind.part;
  String? title, agency, route, planArrive, stopRef;
  TransitMode? routeMode;
  int? planMinutes;
  var planTransfers = 0;
  double? lat, lon;
  final arrivals = <TransitArrival>[];
  final alerts = <String>[];
  final also = <String>[];
  final legs = <TransitLeg>[];
  final stops = <TransitStopHit>[];
  final notes = <String>[];
  var alertsClear = false, alertsUnknown = false, offline = false;
  var noTrips = false, strong = false;

  var body = lines;
  final first = lines.first;
  // A long alert post's tag: "… [1/2 k3]" / "… [2/2 k3]".
  final tag = alertPosts && lines.length == 1
      ? _partTagRe.firstMatch(first)
      : null;
  final post = tag == null ? first : first.substring(0, tag.start);
  final partTag = tag?[2];
  final partIndex = tag == null ? null : int.parse(tag[1]!);
  // The second message of a long alert post: "… the rest".
  if (alertPosts && lines.length == 1 && post.startsWith('… ')) {
    final rest = post.substring(2).trim();
    return TransitReport(
      kind: TransitKind.part,
      title: 'Service alert, continued',
      alerts: ['… $rest'],
      continues: rest,
      partTag: partTag,
      partIndex: partIndex,
    );
  }
  RegExpMatch? h;
  if ((h = _planHeadRe.firstMatch(first)) != null) {
    kind = TransitKind.plan;
    planArrive = h![1];
    planMinutes = int.tryParse(h[2]!);
    planTransfers = int.tryParse(h[3] ?? '') ?? 0;
    title = 'Trip';
    body = lines.sublist(1);
  } else if ((h = _routeHeadRe.firstMatch(first)) != null) {
    kind = TransitKind.route;
    routeMode = TransitMode.fromEmoji(h![1]);
    route = h[2];
    title = h[3];
    agency = h[4]?.toLowerCase();
    body = lines.sublist(1);
  } else if (!_hitRe.hasMatch(first) &&
      (h = _stopHeadRe.firstMatch(first)) != null) {
    kind = TransitKind.stop;
    title = h![1];
    agency = h[2]?.toLowerCase();
    // "alerts [stop] [route]": "🚏 11 @ 3rd Ave & Pike St"
    final at = title!.indexOf(' @ ');
    if (at > 0) {
      route = title.substring(0, at);
      title = title.substring(at + 3);
    }
    body = lines.sublist(1);
  } else if ((h = _searchHeadRe.firstMatch(first)) != null) {
    kind = TransitKind.search;
    title = h![1];
    body = lines.sublist(1);
  } else if (alertPosts &&
      lines.length == 1 &&
      (h = _alertPostRe.firstMatch(post)) != null) {
    // "⚠ CT 201/202: Detour on …": a post of its own (an alerts reply's
    // lines come after its 🚏 header)
    kind = TransitKind.alert;
    title = h![1] ?? 'Service alert';
    alerts.add(h[2]!);
    body = lines.sublist(1);
  }

  for (final l in body) {
    RegExpMatch? m;
    if ((m = _geoRe.firstMatch(l)) != null) {
      lat = double.tryParse(m![1]!);
      lon = double.tryParse(m[2]!);
      stopRef = m[3];
      strong = true;
    } else if (l.startsWith('📴') && l.contains('offline')) {
      offline = true;
    } else if (l.startsWith('📴') && l.toLowerCase().contains('alerts')) {
      alertsUnknown = true;
    } else if (l.startsWith('✅') && l.toLowerCase().contains('no alerts')) {
      alertsClear = true;
    } else if (l.startsWith('😴') && l.toLowerCase().contains('no upcoming')) {
      noTrips = true;
    } else if (l.startsWith('also:')) {
      also.addAll(
        l.substring(5).split(',').map((s) => s.trim()).where((s) => s != ''),
      );
      strong = true;
    } else if (l.startsWith('⚠')) {
      alerts.add(l.replaceFirst(RegExp(r'^⚠\uFE0F?\s*'), ''));
    } else if ((m = _walkRe.firstMatch(l)) != null) {
      legs.add(
        TransitLeg(walk: true, walkMinutes: int.tryParse(m![1]!), to: m[2]!),
      );
    } else if ((m = _rideRe.firstMatch(l)) != null) {
      legs.add(
        TransitLeg(
          mode: TransitMode.fromEmoji(m![1]),
          route: m[2],
          depart: m[3],
          board: m[4],
          to: m[5]!,
          arrive: m[6],
        ),
      );
      strong = true;
    } else if ((m = _hitRe.firstMatch(l)) != null) {
      stops.add(
        TransitStopHit(
          ref: m![1]!,
          name: m[2]!,
          distance: m[3],
          routes: m[4]!.split(',').map((s) => s.trim()).toList(),
        ),
      );
      strong = true;
    } else if (kind == TransitKind.route &&
        (m = _timeOnlyRe.firstMatch(l)) != null) {
      arrivals.add(_arrival(null, route!, m![1]!, m[2]));
    } else if ((m = _arrivalRe.firstMatch(l)) != null) {
      arrivals.add(_arrival(m![1], m[2]!, m[3]!, m[4]));
      if (m[1] != null) strong = true;
    } else if (l.startsWith('➖')) {
      notes.add(l.replaceFirst(RegExp(r'^➖\s*'), ''));
    } else {
      // Not something BusBot writes: a part must be all BusBot lines.
      if (kind == TransitKind.part) return null;
      notes.add(l);
    }
  }
  if (kind == TransitKind.part && !strong) return null;
  if (kind == TransitKind.stop &&
      arrivals.isEmpty &&
      !noTrips &&
      (alerts.isNotEmpty || alertsClear || alertsUnknown || notes.isNotEmpty)) {
    kind = TransitKind.alerts;
  }
  return TransitReport(
    partTag: kind == TransitKind.alert ? partTag : null,
    partIndex: kind == TransitKind.alert ? partIndex : null,
    kind: kind,
    title: title,
    agency: agency,
    route: route,
    routeMode: routeMode,
    stopRef: stopRef,
    lat: lat,
    lon: lon,
    arrivals: arrivals,
    alerts: alerts,
    alertsClear: alertsClear,
    alertsUnknown: alertsUnknown,
    offline: offline,
    noTrips: noTrips,
    also: also,
    planArrive: planArrive,
    planMinutes: planMinutes,
    planTransfers: planTransfers,
    legs: legs,
    stops: stops,
    notes: notes,
  );
}

// ---------------------------------------------------------------- display

/// "4 min", "due", "left" for an arrival at [at], seen at [now].
String transitCountdown(DateTime at, DateTime now) {
  final s = at.difference(now).inSeconds;
  if (s < -120) return 'gone';
  if (s < 60) return 'due';
  final m = (s / 60).floor();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

/// A trip plan's 12-hour "7:50" as a time near [sent].
DateTime? transitPlanTime(String? clock, DateTime sent) {
  if (clock == null) return null;
  final p = clock.split(':');
  final h = int.tryParse(p[0]), m = int.tryParse(p.length > 1 ? p[1] : '');
  if (h == null || m == null) return null;
  final base = sent.subtract(const Duration(hours: 1));
  for (var d = 0; d < 2; d++) {
    for (final hh in [h % 12, h % 12 + 12]) {
      final t = DateTime(sent.year, sent.month, sent.day + d, hh, m);
      if (!t.isBefore(base)) return t;
    }
  }
  return null;
}
