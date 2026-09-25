// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_transport.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentTransport _$StudentTransportFromJson(Map<String, dynamic> json) =>
    StudentTransport(
      studentId: json['student_id'] as String,
      busId: json['bus_id'] as String?,
      pickupLocation: json['pickup_location'] as String?,
      dropLocation: json['drop_location'] as String?,
      routeId: json['route_id'] as String?,
      stopId: json['stop_id'] as String?,
    );

Map<String, dynamic> _$StudentTransportToJson(StudentTransport instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'bus_id': instance.busId,
      'pickup_location': instance.pickupLocation,
      'drop_location': instance.dropLocation,
      'route_id': instance.routeId,
      'stop_id': instance.stopId,
    };
