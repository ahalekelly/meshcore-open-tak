// MeshCore Open TAK - the Watch tab's card body for a transit bot's reply
// (transit_watch.dart): arrivals with ticking countdowns, alerts, trip plans
// and stops found, laid out in full from the bot's few lines.

import 'dart:async';

import 'package:flutter/material.dart';

import 'transit_watch.dart';

/// Colours per mode, readable in light and dark themes.
Color transitModeColor(TransitMode? m) => switch (m) {
  TransitMode.rapid => const Color(0xFFD32F2F),
  TransitMode.rail => const Color(0xFF2E7D32),
  TransitMode.train => const Color(0xFF6A1B9A),
  TransitMode.ferry => const Color(0xFF00838F),
  _ => const Color(0xFF1565C0),
};

IconData transitModeIcon(TransitMode? m) => switch (m) {
  TransitMode.rail => Icons.tram,
  TransitMode.train => Icons.train,
  TransitMode.ferry => Icons.directions_boat,
  _ => Icons.directions_bus,
};

class TransitDetails extends StatefulWidget {
  final TransitReport report;

  /// When the bot sent it: "5 mins" counts from here.
  final DateTime sent;

  /// The full card; otherwise the first few lines.
  final bool expanded;

  const TransitDetails({
    super.key,
    required this.report,
    required this.sent,
    this.expanded = false,
  });

  @override
  State<TransitDetails> createState() => _TransitDetailsState();
}

class _TransitDetailsState extends State<TransitDetails> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Countdowns move on their own.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final sent = widget.sent.toLocal();
    final now = DateTime.now();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final full = widget.expanded;
    final children = <Widget>[];

    void gap([double h = 4]) => children.add(SizedBox(height: h));

    // Stop number and agency.
    final facts = [
      if (r.stopRef != null) 'Stop ${r.stopRef}',
      if (r.kind != TransitKind.plan &&
          r.kind != TransitKind.search &&
          r.kind != TransitKind.alert &&
          (r.kind != TransitKind.part || r.stopRef != null))
        transitAgencyName(r.agency ?? _agencyOfRef(r.stopRef)),
      if (r.route != null && r.routeMode != null) r.routeMode!.label,
    ];
    if (facts.isNotEmpty) {
      children.add(Text(facts.join(' · '), style: t.labelMedium, maxLines: 1));
      gap();
    }

    if (r.offline) {
      children.add(
        _Banner(
          icon: Icons.cloud_off,
          text: 'Live tracking unreachable: timetable times',
          color: scheme.outline,
        ),
      );
      gap();
    }

    // Arrivals.
    final arrivals = full ? r.arrivals : r.arrivals.take(3).toList();
    for (final a in arrivals) {
      children.add(_ArrivalRow(arrival: a, sent: sent, now: now));
    }
    if (!full && r.arrivals.length > arrivals.length) {
      children.add(
        Text(
          '+${r.arrivals.length - arrivals.length} more',
          style: t.bodySmall,
        ),
      );
    }
    if (r.noTrips) {
      children.add(Text('No more trips today', style: t.bodyMedium));
    }

    // Alerts.
    for (final a in full ? r.alerts : r.alerts.take(2)) {
      children.add(
        _Banner(
          icon: Icons.warning_amber_rounded,
          text: a,
          color: const Color(0xFFF9A825),
          maxLines: full ? null : 2,
        ),
      );
      gap(2);
    }
    if (r.alertsClear) {
      children.add(
        const _Banner(
          icon: Icons.check_circle_outline,
          text: 'No alerts',
          color: Color(0xFF43A047),
        ),
      );
    }
    if (r.alertsUnknown) {
      children.add(
        _Banner(
          icon: Icons.cloud_off,
          text: "Live alerts couldn't be checked",
          color: scheme.outline,
        ),
      );
    }

    // A trip plan.
    if (r.kind == TransitKind.plan || r.legs.isNotEmpty) {
      final dur = r.planMinutes;
      final arrive = transitPlanTime(r.planArrive, sent);
      children.add(
        Text(
          [
            if (arrive != null)
              'Arrive ${_clock(context, arrive)}'
                  '${arrive.isAfter(now) ? ' (in ${transitCountdown(arrive, now)})' : ''}',
            if (dur != null) '$dur min trip',
            if (r.planTransfers > 0)
              '${r.planTransfers} transfer${r.planTransfers > 1 ? 's' : ''}',
            'timetable',
          ].join(' · '),
          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      gap();
      for (final l in full ? r.legs : r.legs.take(2)) {
        children.add(_LegRow(leg: l, sent: sent, now: now));
      }
      if (!full && r.legs.length > 2) {
        children.add(
          Text('+${r.legs.length - 2} more steps', style: t.bodySmall),
        );
      }
    }

    // Stops found.
    for (final s in full ? r.stops : r.stops.take(2)) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(s.ref, style: t.labelMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    s.name,
                    ?s.distance,
                    if (s.routes.isNotEmpty) 'Routes ${s.routes.join(', ')}',
                  ].join(' · '),
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (full) {
      if (r.also.isNotEmpty) {
        gap();
        children.add(
          Text('Same stop number at: ${r.also.join(', ')}', style: t.bodySmall),
        );
      }
      for (final n in r.notes) {
        children.add(Text(n, style: t.bodySmall));
      }
      gap();
      children.add(
        Text(
          r.arrivals.isEmpty
              ? 'Sent ${_clock(context, sent)}'
              : 'Times from ${_clock(context, sent)}; countdowns keep running',
          style: t.bodySmall?.copyWith(color: scheme.outline),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// "ct 1120" -> "ct"; a bare number is the default agency's.
String? _agencyOfRef(String? ref) {
  if (ref == null) return null;
  final sp = ref.indexOf(' ');
  return sp > 0 ? ref.substring(0, sp) : null;
}

/// "stop 1121" for a number, a stop's name as it is.
String _stopWords(String s) =>
    RegExp(r'^([a-z]{2,4} )?[\w.-]*\d[\w.-]*$').hasMatch(s) ? 'stop $s' : s;

String _clock(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

class _ArrivalRow extends StatelessWidget {
  final TransitArrival arrival;
  final DateTime sent, now;
  const _ArrivalRow({
    required this.arrival,
    required this.sent,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final a = arrival;
    final at = a.at(sent);
    final left = at == null ? null : transitCountdown(at, now);
    final gone = left == 'gone';
    final colour = transitModeColor(a.mode);
    return Opacity(
      opacity: gone ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(transitModeIcon(a.mode), size: 14, color: Colors.white),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      a.route,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                left ?? '',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: left == 'due' ? scheme.primary : null,
                ),
              ),
            ),
            if (at != null) Text(_clock(context, at), style: t.bodyMedium),
            const SizedBox(width: 8),
            Tooltip(
              message: a.scheduled
                  ? 'From the timetable'
                  : 'Live tracking when sent',
              child: Icon(
                a.scheduled ? Icons.schedule : Icons.sensors,
                size: 16,
                color: a.scheduled ? scheme.outline : const Color(0xFF43A047),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  final TransitLeg leg;
  final DateTime sent, now;
  const _LegRow({required this.leg, required this.sent, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = leg;
    if (l.walk) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.directions_walk, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Walk ${l.walkMinutes ?? '?'} min to '
                '${l.to == 'destination' ? 'your destination' : _stopWords(l.to)}',
                style: t.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final dep = transitPlanTime(l.depart, sent);
    final arr = transitPlanTime(l.arrive, sent);
    final colour = transitModeColor(l.mode);
    final leaves = dep != null && dep.isAfter(now)
        ? ' · leaves in ${transitCountdown(dep, now)}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(transitModeIcon(l.mode), size: 20, color: colour),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.route ?? ''} '
                  '${dep == null ? l.depart ?? '' : _clock(context, dep)}'
                  '${l.board == null ? '' : ' from ${_stopWords(l.board!)}'}$leaves',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'to ${l.to}'
                  '${arr == null ? '' : ', arrive ${_clock(context, arr)}'}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final int? maxLines;
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
