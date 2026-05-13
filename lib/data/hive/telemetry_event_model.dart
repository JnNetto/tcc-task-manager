import 'package:hive/hive.dart';

part 'telemetry_event_model.g.dart';

@HiveType(typeId: 10)
class TelemetryEventModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String participantId;
  @HiveField(2)
  final String sessionId;
  @HiveField(3)
  final String eventType;
  @HiveField(4)
  final DateTime timestamp;
  @HiveField(5)
  final Map<String, dynamic>? data;
  @HiveField(6)
  final String prototype;
  @HiveField(7)
  final bool networkDegraded;
  @HiveField(8)
  final int sequenceNumber;
  @HiveField(9)
  final int dayOfStudy;

  TelemetryEventModel({
    required this.id,
    required this.participantId,
    required this.sessionId,
    required this.eventType,
    required this.timestamp,
    this.data,
    required this.prototype,
    required this.networkDegraded,
    required this.sequenceNumber,
    required this.dayOfStudy,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'participantId': participantId,
    'sessionId': sessionId,
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
    'prototype': prototype,
    'networkDegraded': networkDegraded,
    'sequenceNumber': sequenceNumber,
    'dayOfStudy': dayOfStudy,
  };
}
