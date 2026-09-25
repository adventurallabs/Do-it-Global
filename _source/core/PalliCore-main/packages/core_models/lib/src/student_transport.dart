import 'package:json_annotation/json_annotation.dart';

part 'student_transport.g.dart';

/// How one child gets to school.
///
/// The office knows "bus 3, picked up at the temple corner" long before
/// anybody draws that as a route with mapped stops — so [busId],
/// [pickupLocation] and [dropLocation] are what admission fills in, and
/// [routeId]/[stopId] stay for the live bus tracker to use once a route
/// exists. All of them are optional: a family can say "yes, the bus" on the
/// first day and work out the corner later.
@JsonSerializable(fieldRename: FieldRename.snake)
class StudentTransport {
  final String studentId;

  /// Which bus. Null while the family has said they need transport but the
  /// office has not assigned one.
  final String? busId;

  final String? pickupLocation;
  final String? dropLocation;

  /// The tracker's view, when one has been drawn.
  final String? routeId;
  final String? stopId;

  const StudentTransport({
    required this.studentId,
    this.busId,
    this.pickupLocation,
    this.dropLocation,
    this.routeId,
    this.stopId,
  });

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  /// True once there is enough to actually put the child on a bus. This is
  /// what decides whether the office still owes the detail.
  bool get isComplete => _has(busId) && _has(pickupLocation) && _has(dropLocation);

  /// Something has been recorded, but not all of it.
  bool get isPartial =>
      !isComplete && (_has(busId) || _has(pickupLocation) || _has(dropLocation));

  List<String> get missing => [
        if (!_has(busId)) 'bus',
        if (!_has(pickupLocation)) 'pickup point',
        if (!_has(dropLocation)) 'drop point',
      ];

  factory StudentTransport.fromJson(Map<String, dynamic> json) =>
      _$StudentTransportFromJson(json);
  Map<String, dynamic> toJson() => _$StudentTransportToJson(this);
}
