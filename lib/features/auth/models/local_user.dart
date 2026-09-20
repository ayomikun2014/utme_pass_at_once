import 'package:hive/hive.dart';

part 'local_user.g.dart';

@HiveType(typeId: 0)
class LocalUser extends HiveObject {
  @HiveField(0)
  final String uid;

  @HiveField(1)
  final String email;

  @HiveField(2)
  final String displayName;

  @HiveField(3)
  final Map<String, dynamic> examSelections;

  @HiveField(4)
  final DateTime premiumExpiryDate;

  @HiveField(5)
  final DateTime lastUpdated;

  @HiveField(6)
  final String? gender;

  @HiveField(7)
  final String? dob;

  @HiveField(8)
  final String? hobbies;

  @HiveField(9)
  final String? interests;

  @HiveField(10)
  final String? schoolStatus;

  @HiveField(11)
  final bool isPremium;

  @HiveField(12)
  final String? deviceId;

  @HiveField(13)
  final Map<String, dynamic>? deviceInfo;

  @HiveField(14)
  final String? phone;

  @HiveField(15)
  final String? referredBy;

  LocalUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.examSelections,
    required this.premiumExpiryDate,
    required this.lastUpdated,

    // Made nullable for backward compatibility
    this.gender,
    this.dob,
    this.hobbies,
    this.interests,
    this.schoolStatus,
    this.phone,
    this.isPremium = false,
    this.deviceId,
    this.deviceInfo,
    this.referredBy,
  });

  bool isPremiumOnDevice(String currentDeviceId) {
    if (DateTime.now().isAfter(premiumExpiryDate)) return false;
    for (final entry in examSelections.values) {
      if (entry is Map && entry['deviceId'] == currentDeviceId) return true;
    }
    return false;
  }
}
