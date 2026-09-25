import 'package:json_annotation/json_annotation.dart';

part 'bus.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Bus {
  final String id;
  final String busNumber;
  final String driverName;
  final String driverContact;
  final double? latitude;
  final double? longitude;
  final DateTime? lastUpdate;

  Bus({
    required this.id,
    required this.busNumber,
    required this.driverName,
    required this.driverContact,
    this.latitude,
    this.longitude,
    this.lastUpdate,
  });

  factory Bus.fromJson(Map<String, dynamic> json) => _$BusFromJson(json);
  Map<String, dynamic> toJson() => _$BusToJson(this);
}
