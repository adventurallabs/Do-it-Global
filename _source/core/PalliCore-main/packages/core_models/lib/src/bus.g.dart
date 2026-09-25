// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Bus _$BusFromJson(Map<String, dynamic> json) => Bus(
  id: json['id'] as String,
  busNumber: json['bus_number'] as String,
  driverName: json['driver_name'] as String,
  driverContact: json['driver_contact'] as String,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  lastUpdate: json['last_update'] == null
      ? null
      : DateTime.parse(json['last_update'] as String),
);

Map<String, dynamic> _$BusToJson(Bus instance) => <String, dynamic>{
  'id': instance.id,
  'bus_number': instance.busNumber,
  'driver_name': instance.driverName,
  'driver_contact': instance.driverContact,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'last_update': instance.lastUpdate?.toIso8601String(),
};
