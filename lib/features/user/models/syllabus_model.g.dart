// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'syllabus_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyllabusModelAdapter extends TypeAdapter<SyllabusModel> {
  @override
  final int typeId = 2;

  @override
  SyllabusModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyllabusModel(
      id: fields[0] as String,
      name: fields[1] as String,
      examType: fields[2] as String,
      storagePath: fields[3] as String,
      localEncryptedPath: fields[4] as String,
      isDownloaded: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SyllabusModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.examType)
      ..writeByte(3)
      ..write(obj.storagePath)
      ..writeByte(4)
      ..write(obj.localEncryptedPath)
      ..writeByte(5)
      ..write(obj.isDownloaded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyllabusModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
