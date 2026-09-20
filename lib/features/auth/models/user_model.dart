import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final String role;
  final DateTime createdAt;

  // Premium & Device Binding
  final Map<String, dynamic>? _examSelections;
  Map<String, dynamic> get examSelections =>
      _examSelections ?? <String, dynamic>{};
  final DateTime premiumExpiryDate;
  final bool isPremiumGlobal;

  bool get isPremium {
    if (isPremiumGlobal && premiumExpiryDate.isAfter(DateTime.now()))
      return true;
    return hasAnyActiveExam();
  }

  final String? deviceId;
  final Map<String, dynamic>? deviceInfo;

  final String gender;
  final String dob;
  final String hobbies;
  final String interests;
  final String schoolStatus;
  final String? referredBy;
  final Map<String, String> referredCenters;
  final Map<String, bool> suspendedCenters;

  // NOTIFICATION SETTINGS
  final bool generalNotificationEnabled;

  // ADMIN CONTROL
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    this.role = 'user',
    required this.createdAt,
    Map<String, dynamic>? examSelections,
    required this.premiumExpiryDate,
    bool isPremium = false,
    this.deviceId,
    this.deviceInfo,

    // Defaulting to empty strings for new signups
    this.gender = '--',
    this.dob = '--',
    this.hobbies = '--',
    this.interests = '--',
    this.schoolStatus = '',
    this.generalNotificationEnabled = true,
    this.isActive = true,
    this.referredBy,
    this.referredCenters = const {},
    this.suspendedCenters = const {},
  }) : isPremiumGlobal = isPremium,
       _examSelections = examSelections ?? <String, dynamic>{};

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phone: (data['phone'] != null && data['phone'].toString().isNotEmpty)
          ? data['phone']
          : '--',
      role: data['role'] ?? 'user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // CRITICAL FIX: Sanitize the map to remove Firestore Timestamps before Hive sees them
      examSelections: data['examSelections'] != null
          ? _sanitizeMap(data['examSelections'] as Map)
          : <String, dynamic>{},

      premiumExpiryDate:
          (data['premiumExpiryDate'] as Timestamp?)?.toDate() ??
          DateTime(DateTime.now().year, 12, 31, 23, 59, 59),
      isPremium: data['isPremium'] ?? false,
      deviceId: data['deviceId'],
      deviceInfo: data['deviceInfo'] != null
          ? Map<String, dynamic>.from(data['deviceInfo'])
          : null,
      gender: data['gender'] ?? '--',
      dob: data['dob'] ?? '--',
      hobbies: data['hobbies'] ?? '--',
      interests: data['interests'] ?? '--',
      schoolStatus: data['schoolStatus'] ?? 'Department of --',
      generalNotificationEnabled: data['generalNotificationEnabled'] ?? true,
      isActive: data['isActive'] ?? true,
      referredBy: data['referredBy'] as String?,
      referredCenters: Map<String, String>.from(data['referredCenters'] ?? {}),
      suspendedCenters: Map<String, bool>.from(data['suspendedCenters'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'examSelections': examSelections,
      'premiumExpiryDate': Timestamp.fromDate(premiumExpiryDate),
      'isPremium': isPremiumGlobal,
      'deviceId': deviceId,
      'deviceInfo': deviceInfo,

      // Save new fields
      'gender': gender,
      'dob': dob,
      'hobbies': hobbies,
      'interests': interests,
      'schoolStatus': schoolStatus,
      'generalNotificationEnabled': generalNotificationEnabled,
      'isActive': isActive,
      'referredBy': referredBy,
      'referredCenters': referredCenters,
      'suspendedCenters': suspendedCenters,
    };
  }

  bool isPremiumOnDevice(String currentDeviceId) {
    // Only grant globally if they have a global premium override
    if (isPremiumGlobal && premiumExpiryDate.isAfter(DateTime.now()))
      return true;

    for (final entry in examSelections.values) {
      if (entry is Map && entry['deviceId'] == currentDeviceId) return true;
    }
    return false;
  }

  bool hasActiveExam(String examName, String currentDeviceId) {
    String normalized = examName.toLowerCase().trim();

    final selection = examSelections[normalized];
    if (selection is Map && selection['deviceId'] == currentDeviceId) {
      // THE FIX: Check if there is at least ONE active, unexpired package
      if (selection['institutions'] is Map) {
        final institutions = selection['institutions'] as Map;
        for (final inst in institutions.values) {
          if (inst is Map) {
            if (inst['expiresAt'] != null) {
              final expiresAt = inst['expiresAt'] is DateTime
                  ? inst['expiresAt'] as DateTime
                  : (inst['expiresAt'] as Timestamp).toDate();
              if (expiresAt.isAfter(DateTime.now())) {
                return true; // Found an active one!
              }
            } else {
              return true; // Legacy package without expiration date
            }
          }
        }
      }
    }
    return false;
  }

  bool isPremiumForExamAnyDevice(String examName) {
    String normalized = examName.toLowerCase().trim();

    final selection = examSelections[normalized];
    if (selection is Map && selection.containsKey('deviceId')) {
      // THE FIX: Must have at least one unexpired package
      if (selection['institutions'] is Map) {
        final institutions = selection['institutions'] as Map;
        for (final inst in institutions.values) {
          if (inst is Map) {
            if (inst['expiresAt'] != null) {
              final expiresAt = inst['expiresAt'] is DateTime
                  ? inst['expiresAt'] as DateTime
                  : (inst['expiresAt'] as Timestamp).toDate();
              if (expiresAt.isAfter(DateTime.now())) return true;
            } else {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool hasAnyActiveExam() {
    for (final selection in examSelections.values) {
      if (selection is Map && selection['institutions'] is Map) {
        final institutions = selection['institutions'] as Map;
        for (final inst in institutions.values) {
          if (inst is Map) {
            if (inst['expiresAt'] != null) {
              final expiresAt = inst['expiresAt'] is DateTime
                  ? inst['expiresAt'] as DateTime
                  : (inst['expiresAt'] as Timestamp).toDate();
              if (expiresAt.isAfter(DateTime.now())) return true;
            } else {
              return true; // Legacy package
            }
          }
        }
      }
    }
    return false;
  }

  List<Map<String, dynamic>> getActivePackages() {
    final activePackages = <Map<String, dynamic>>[];
    examSelections.forEach((examType, selection) {
      if (selection is Map && selection['institutions'] is Map) {
        final institutions = selection['institutions'] as Map;
        institutions.forEach((instKey, instData) {
          if (instData is Map) {
            DateTime? expiresAt;
            if (instData['expiresAt'] != null) {
              expiresAt = instData['expiresAt'] is DateTime
                  ? instData['expiresAt'] as DateTime
                  : (instData['expiresAt'] as Timestamp).toDate();
            }
            if (expiresAt == null || expiresAt.isAfter(DateTime.now())) {
              activePackages.add({
                'examType': examType,
                'institutionId': instData['institutionId'] ?? instKey,
                'sectionId': instData['sectionId'] ?? '',
                'sectionName': instData['sectionName'] ?? '',
                'expiresAt': expiresAt,
                'subjects':
                    instData['initialSubjectsFallback'] ??
                    instData['subjects'] ??
                    [],
              });
            }
          }
        });
      }
    });
    return activePackages;
  }

  /// Returns the list of center IDs the user has purchased for an exam type.
  List<String> getExamCenters(String examType) {
    String normalized = examType.toLowerCase().trim();

    final selection = examSelections[normalized];
    if (selection is! Map || selection['institutions'] is! Map) return [];

    final institutions = selection['institutions'] as Map;
    final activeCenters = <String>[];

    // THE FIX: Only return centers that are NOT expired
    institutions.forEach((key, value) {
      if (value is Map) {
        if (value['expiresAt'] != null) {
          final expiresAt = value['expiresAt'] as DateTime;
          if (expiresAt.isAfter(DateTime.now())) {
            activeCenters.add(key.toString());
          }
        } else {
          // Legacy support for users activated before this update
          activeCenters.add(key.toString());
        }
      }
    });

    return activeCenters;
  }

  /// Returns the list of subjects already bought for a specific exam + center.
  List<String> getSubjectsForCenter(String examType, String center) {
    try {
      String normalized = examType.toLowerCase().trim();

      final selection = examSelections[normalized];
      if (selection == null || selection is! Map) return [];

      final centers = selection['institutions'];
      if (centers == null || centers is! Map) return [];

      final centerData = centers[center];
      if (centerData == null || centerData is! Map) return [];

      // THE FIX: Look for the new architecture variable, fallback to legacy
      final subjects =
          centerData['initialSubjectsFallback'] ?? centerData['subjects'];
      if (subjects == null || subjects is! List) return [];

      return subjects.map((e) => e.toString().toLowerCase()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns the section details (id, name) if available for the given exam + center.
  Map<String, String>? getSectionForInstitution(
    String examType,
    String center,
  ) {
    try {
      String normalized = examType.toLowerCase().trim();

      final selection = examSelections[normalized];
      if (selection == null || selection is! Map) return null;

      final centers = selection['institutions'];
      if (centers == null || centers is! Map) return null;

      final centerData = centers[center];
      if (centerData == null || centerData is! Map) return null;

      final sectionId =
          centerData['sectionId'] ?? centerData['selectedSectionId'];
      final sectionName =
          centerData['sectionName'] ?? centerData['selectedSectionName'];

      if (sectionId != null && sectionId.toString().isNotEmpty) {
        return {
          'id': sectionId.toString(),
          'name': sectionName?.toString() ?? 'Section',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- HIVE SANITIZER HELPER ---
  // Recursively goes through the complex map and converts Timestamps to DateTimes
  static Map<String, dynamic> _sanitizeMap(Map<dynamic, dynamic> map) {
    final sanitized = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key.toString()] = value.toDate();
      } else if (value is Map) {
        sanitized[key.toString()] = _sanitizeMap(value);
      } else if (value is List) {
        sanitized[key.toString()] = value.map((e) {
          if (e is Timestamp) return e.toDate();
          if (e is Map) return _sanitizeMap(e);
          return e;
        }).toList();
      } else {
        sanitized[key.toString()] = value;
      }
    });
    return sanitized;
  }
}
