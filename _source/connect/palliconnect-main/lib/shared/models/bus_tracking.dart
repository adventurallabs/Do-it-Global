import 'dart:math' as math;

/// A latitude/longitude pair. Plain Dart on purpose — the tracking screen no
/// longer needs a map SDK (or its API key) to show where the bus is.
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  /// Straight-line distance in metres (haversine).
  double distanceTo(GeoPoint other) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) * math.cos(rad(other.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.toDouble()));
  }
}

enum BusTripStatus { scheduled, tripStarted, tripEnded }

class BusRoute {
  final String id;
  final String routeName;
  final List<BusStop> stops;

  BusRoute({required this.id, required this.routeName, required this.stops});
}

class BusStop {
  final String id;
  final String name;
  final GeoPoint location;
  final int sequence;

  BusStop({required this.id, required this.name, required this.location, required this.sequence});
}

class BusLocation {
  final String busId;
  final GeoPoint location;
  final double? speedKmph;
  final DateTime recordedAt;

  BusLocation({required this.busId, required this.location, this.speedKmph, required this.recordedAt});
}

class BusTripSession {
  final String busId;
  final String routeId;
  final BusTripStatus status;
  final String? etaToChildStop;

  BusTripSession({required this.busId, required this.routeId, required this.status, this.etaToChildStop});
}

class BusInfo {
  final String id;
  final String busNumber;
  final String driverName;
  final String driverContact;

  BusInfo({
    required this.id,
    required this.busNumber,
    required this.driverName,
    required this.driverContact,
  });
}

/// Everything the tracking screen needs for the signed-in parent's child:
/// which bus/route they're assigned to, the stop list, and (if any) the
/// bus's own stop on that route.
class StudentBusAssignment {
  final BusInfo bus;
  final BusRoute route;
  final String? stopId;

  StudentBusAssignment({required this.bus, required this.route, this.stopId});
}
