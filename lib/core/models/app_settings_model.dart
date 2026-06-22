import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
// PHONE MODEL
// ─────────────────────────────────────────────────────────────
class PhoneDetail {
  final String id;
  final String phoneNumber;
  final String label;
  final bool isPrimary;

  const PhoneDetail({
    required this.id,
    required this.phoneNumber,
    required this.label,
    this.isPrimary = false,
  });

  factory PhoneDetail.fromMap(Map<String, dynamic> map) {
    return PhoneDetail(
      id: (map['id'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      isPrimary: (map['isPrimary'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'phoneNumber': phoneNumber.trim(),
    'label': label.trim(),
    'isPrimary': isPrimary,
  };
}

// ─────────────────────────────────────────────────────────────
// BANK MODEL
// ─────────────────────────────────────────────────────────────
class BankDetail {
  final String id;
  final String accountName;
  final String accountNumber;
  final String bankName;

  const BankDetail({
    required this.id,
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
  });

  factory BankDetail.fromMap(Map<String, dynamic> map) {
    return BankDetail(
      id: (map['id'] as String?) ?? '',
      accountName: (map['accountName'] as String?) ?? '',
      accountNumber: (map['accountNumber'] as String?) ?? '',
      bankName: (map['bankName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'accountName': accountName.trim(),
    'accountNumber': accountNumber.trim(),
    'bankName': bankName.trim(),
  };
}

// ─────────────────────────────────────────────────────────────
// APP SETTINGS MODEL
// ─────────────────────────────────────────────────────────────
class AppSettingsModel {
  // ── System
  final bool maintenanceMode;

  // ── NEW: Payment Gateway Control
  final bool paymentGatewayEnabled;

  // ── App Version
  final String latestAppVersion; // FIXED: Matched to Admin Panel
  final String minAppVersion;
  final bool forceUpdate;
  final bool showUpdatePrompt; // FIXED: Added missing field
  final String updateTitle;
  final String updateMessage;
  final String androidUpdateUrl;
  final String iosUpdateUrl;

  // ── Pricing
  final int jambPrice;
  final int waecPrice;
  final int necoPrice;
  final int postUtmePrice;

  // ── Bank
  final List<BankDetail> bankDetails;

  // ── Contact
  final String contactEmail;
  final List<PhoneDetail> supportPhones;
  final String whatsappNumber;

  // ── Links
  final String playStoreUrl;
  final String appStoreUrl;
  final String shareLink;

  final DateTime? updatedAt;

  const AppSettingsModel({
    required this.maintenanceMode,
    required this.paymentGatewayEnabled, // Added
    required this.latestAppVersion,      // Renamed
    required this.minAppVersion,
    required this.forceUpdate,
    required this.showUpdatePrompt,      // Added
    required this.updateTitle,
    required this.updateMessage,
    required this.androidUpdateUrl,
    required this.iosUpdateUrl,
    required this.jambPrice,
    required this.waecPrice,
    required this.necoPrice,
    required this.postUtmePrice,
    required this.bankDetails,
    required this.contactEmail,
    required this.supportPhones,
    required this.whatsappNumber,
    required this.playStoreUrl,
    required this.appStoreUrl,
    required this.shareLink,
    this.updatedAt,
  });

  // ─────────────────────────────────────────────────────────────
  // DEFAULTS (VERY IMPORTANT)
  // ─────────────────────────────────────────────────────────────
  factory AppSettingsModel.initial() => const AppSettingsModel(
    maintenanceMode: false,
    paymentGatewayEnabled: true, // Default to true
    latestAppVersion: '1.0.0',
    minAppVersion: '1.0.0',
    forceUpdate: false,
    showUpdatePrompt: true, // Default to true
    updateTitle: 'New Update Available',
    updateMessage:
    'Please update your app to continue enjoying the latest features.',
    androidUpdateUrl: '',
    iosUpdateUrl: '',
    jambPrice: 3000,
    waecPrice: 3000,
    necoPrice: 3000,
    postUtmePrice: 3500,
    bankDetails: [],
    contactEmail: '',
    supportPhones: [],
    whatsappNumber: '',
    playStoreUrl: '',
    appStoreUrl: '',
    shareLink: '',
  );

  // ─────────────────────────────────────────────────────────────
  // FROM FIRESTORE
  // ─────────────────────────────────────────────────────────────
  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    final bankList = map['bankDetails'];
    final phoneList = map['supportPhones'];

    return AppSettingsModel(
      maintenanceMode: (map['maintenanceMode'] as bool?) ?? false,

      // Syncs with Admin Kill-Switch
      paymentGatewayEnabled: (map['paymentGatewayEnabled'] as bool?) ?? true,

      // Syncs with Admin Versioning
      latestAppVersion: (map['latestAppVersion'] as String?) ?? '1.0.0',
      minAppVersion: (map['minAppVersion'] as String?) ?? '1.0.0',
      forceUpdate: (map['forceUpdate'] as bool?) ?? false,
      showUpdatePrompt: (map['showUpdatePrompt'] as bool?) ?? true,

      updateTitle: (map['updateTitle'] as String?) ?? 'New Update Available',
      updateMessage:
      (map['updateMessage'] as String?) ??
          'Please update your app to continue enjoying the latest features.',

      androidUpdateUrl: (map['androidUpdateUrl'] as String?) ?? '',
      iosUpdateUrl: (map['iosUpdateUrl'] as String?) ?? '',

      jambPrice: (map['jambPrice'] as num?)?.toInt() ?? 3000,
      waecPrice: (map['waecPrice'] as num?)?.toInt() ?? 3000,
      necoPrice: (map['necoPrice'] as num?)?.toInt() ?? 3000,
      postUtmePrice: (map['postUtmePrice'] as num?)?.toInt() ?? 3500,

      bankDetails: bankList is List
          ? bankList
          .whereType<Map<String, dynamic>>() // Safer casting
          .map((e) => BankDetail.fromMap(e))
          .toList()
          : [],

      contactEmail: (map['contactEmail'] as String?) ?? '',

      supportPhones: phoneList is List
          ? phoneList
          .whereType<Map<String, dynamic>>() // Safer casting
          .map((e) => PhoneDetail.fromMap(e))
          .toList()
          : [],

      whatsappNumber: (map['whatsappNumber'] as String?) ?? '',

      playStoreUrl: (map['playStoreUrl'] as String?) ?? '',
      appStoreUrl: (map['appStoreUrl'] as String?) ?? '',
      shareLink: (map['shareLink'] as String?) ?? '',

      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : map['updatedAt'] is String
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }
}