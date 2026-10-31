# Transit cards in the Watch tab (MeshCore Open TAK)

Watch a transit bot's channel (for example `#transit`, answered by [BusBot 2.0](https://github.com/jade-on-mesh/BusBot-2.0)) and its replies show in the Watch tab as full transit cards instead of a few lines of text. Mesh messages are short, so the bot sends a compact reply; the app lays it out in full:

- **Arrivals**: a coloured badge per route with its mode (bus, RapidRide, light rail or streetcar, train, ferry), the clock time it arrives, and a countdown that keeps running after the reply arrived ("5 min", "due", then greyed out once it has gone). A sensor icon marks live tracking, a clock icon timetable times.
- **The stop**: its number and agency (King County Metro, Sound Transit, Community Transit, Pierce Transit, Everett Transit, Intercity Transit, Kitsap Transit, Washington State Ferries, Seattle Center Monorail), and, with BusBot's position line, a place on the map with **Show on map** and Bloodhound.
- **Alerts**: each in a warning band; the card turns yellow when there are any. "No alerts" and "couldn't check" are shown as such. On a channel named for transit, the bot's own alert posts become alert cards too.
- **Offline**: when the bot couldn't reach live tracking, a band says the times are from the timetable.
- **Trip plans** (`go A to B`): the arrival time with a countdown, trip length and transfers, then each ride (route, departure with "leaves in …", stop, where to get off) and walk as steps.
- **Stops found** (`stops`, `near`): each stop's number, name, distance and routes.

Collapsed, a card shows the first few rows; tap it for everything, including other agencies' stops with the same number. A reply the bot split over two messages is joined back into one card.

The format BusBot writes is described in its README; the parser is `lib/team/transit_watch.dart` (tests in `test/team/transit_watch_test.dart`) and the card `lib/team/transit_card.dart`. Wadamesh TAK reads the same replies on standalones.
