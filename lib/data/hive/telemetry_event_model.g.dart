// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TelemetryEventModelAdapter extends TypeAdapter<TelemetryEventModel> {
  @override
  final int typeId = 10;

  @override
  TelemetryEventModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TelemetryEventModel(
      id: fields[0] as String,
      participantId: fields[1] as String,
      sessionId: fields[2] as String,
      eventType: fields[3] as String,
      timestamp: fields[4] as DateTime,
      data: (fields[5] as Map?)?.cast<String, dynamic>(),
      prototype: fields[6] as String,
      networkDegraded: fields[7] as bool,
      sequenceNumber: fields[8] as int,
      dayOfStudy: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TelemetryEventModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.participantId)
      ..writeByte(2)
      ..write(obj.sessionId)
      ..writeByte(3)
      ..write(obj.eventType)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.data)
      ..writeByte(6)
      ..write(obj.prototype)
      ..writeByte(7)
      ..write(obj.networkDegraded)
      ..writeByte(8)
      ..write(obj.sequenceNumber)
      ..writeByte(9)
      ..write(obj.dayOfStudy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelemetryEventModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
