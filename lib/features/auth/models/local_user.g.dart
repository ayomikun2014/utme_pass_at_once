// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalUserAdapter extends TypeAdapter<LocalUser> {
  @override
  final int typeId = 0;

  @override
  LocalUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalUser(
      uid: fields[0] as String,
      email: fields[1] as String,
      displayName: fields[2] as String,
      examSelections: (fields[3] as Map).cast<String, dynamic>(),
      premiumExpiryDate: fields[4] as DateTime,
      lastUpdated: fields[5] as DateTime,
      gender: fields[6] as String?,
      dob: fields[7] as String?,
      hobbies: fields[8] as String?,
      interests: fields[9] as String?,
      schoolStatus: fields[10] as String?,
      phone: fields[14] as String?,
      isPremium: fields[11] as bool,
      deviceId: fields[12] as String?,
      deviceInfo: (fields[13] as Map?)?.cast<String, dynamic>(),
      referredBy: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalUser obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.examSelections)
      ..writeByte(4)
      ..write(obj.premiumExpiryDate)
      ..writeByte(5)
      ..write(obj.lastUpdated)
      ..writeByte(6)
      ..write(obj.gender)
      ..writeByte(7)
      ..write(obj.dob)
      ..writeByte(8)
      ..write(obj.hobbies)
      ..writeByte(9)
      ..write(obj.interests)
      ..writeByte(10)
      ..write(obj.schoolStatus)
      ..writeByte(11)
      ..write(obj.isPremium)
      ..writeByte(12)
      ..write(obj.deviceId)
      ..writeByte(13)
      ..write(obj.deviceInfo)
      ..writeByte(14)
      ..write(obj.phone)
      ..writeByte(15)
      ..write(obj.referredBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
