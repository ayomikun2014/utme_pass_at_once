import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
//  VOUCHER STATUS ENUM
//  A voucher moves through exactly three stages:
//   generated → sold → used
// ─────────────────────────────────────────────
enum VoucherStatus { generated, sold, used }

extension VoucherStatusX on VoucherStatus {
  String get value {
    switch (this) {
      case VoucherStatus.generated:
        return 'generated';
      case VoucherStatus.sold:
        return 'sold';
      case VoucherStatus.used:
        return 'used';
    }
  }

  static VoucherStatus fromString(String? raw) {
    switch (raw) {
      case 'sold':
        return VoucherStatus.sold;
      case 'used':
        return VoucherStatus.used;
      default:
        return VoucherStatus.generated;
    }
  }
}

// ─────────────────────────────────────────────
//  VOUCHER MODEL
// ─────────────────────────────────────────────
class VoucherModel {
  /// Firestore document ID — same value as [code].
  final String id;

  /// Human-readable code, e.g. "JAM-A3K9-XQ2P".
  final String code;

  /// "jamb" | "waec" | "neco"
  final String examType;

  /// Price in Naira. Null for promo / free codes.
  final double? price;

  /// Current lifecycle stage.
  final VoucherStatus status;

  // ── Generation ──────────────────────────────
  /// UID of the admin who created this voucher.
  final String generatedByAdminUid;

  /// When the document was created in Firestore.
  final DateTime createdAt;

  // ── Sale ────────────────────────────────────
  /// UID of the user who bought this voucher.
  final String? soldToUid;

  /// "paystack" | "transfer"
  final String? paymentMethod;

  /// Paystack reference ID or bank-transfer receipt number.
  final String? paymentReference;

  /// When payment was confirmed and status flipped to 'sold'.
  final DateTime? soldAt;

  /// UID of the admin who confirmed a manual transfer (null for Paystack).
  final String? confirmedByAdminUid;

  // ── Activation ──────────────────────────────
  /// UID of the end-user who activated the voucher on the unlock screen.
  final String? usedByUid;

  /// When the voucher was activated.
  final DateTime? usedAt;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.examType,
    this.price,
    required this.status,
    required this.generatedByAdminUid,
    required this.createdAt,
    this.soldToUid,
    this.paymentMethod,
    this.paymentReference,
    this.soldAt,
    this.confirmedByAdminUid,
    this.usedByUid,
    this.usedAt,
  });

  // ── Convenience ─────────────────────────────
  bool get isGenerated => status == VoucherStatus.generated;
  bool get isSold => status == VoucherStatus.sold;
  bool get isUsed => status == VoucherStatus.used;

  // ── fromMap ──────────────────────────────────
  factory VoucherModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? ts(dynamic v) =>
        v is Timestamp ? v.toDate() : null;

    return VoucherModel(
      id: docId,
      code: (map['code'] as String?) ?? docId,
      examType: (map['examType'] as String?) ?? '',
      price: (map['price'] as num?)?.toDouble(),
      status: VoucherStatusX.fromString(map['status'] as String?),
      generatedByAdminUid:
      (map['generatedByAdminUid'] as String?) ?? '',
      createdAt: ts(map['createdAt']) ?? DateTime.now(),
      soldToUid: map['soldToUid'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      paymentReference: map['paymentReference'] as String?,
      soldAt: ts(map['soldAt']),
      confirmedByAdminUid:
      map['confirmedByAdminUid'] as String?,
      usedByUid: map['usedByUid'] as String?,
      usedAt: ts(map['usedAt']),
    );
  }

  // ── toMap ────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'code': code,
    'examType': examType,
    if (price != null) 'price': price,
    'status': status.value,
    'generatedByAdminUid': generatedByAdminUid,
    'createdAt': FieldValue.serverTimestamp(),
    if (soldToUid != null) 'soldToUid': soldToUid,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (paymentReference != null)
      'paymentReference': paymentReference,
    if (soldAt != null)
      'soldAt': Timestamp.fromDate(soldAt!),
    if (confirmedByAdminUid != null)
      'confirmedByAdminUid': confirmedByAdminUid,
    if (usedByUid != null) 'usedByUid': usedByUid,
    if (usedAt != null) 'usedAt': Timestamp.fromDate(usedAt!),
  };

  // ── copyWith ─────────────────────────────────
  VoucherModel copyWith({
    String? id,
    String? code,
    String? examType,
    double? price,
    VoucherStatus? status,
    String? generatedByAdminUid,
    DateTime? createdAt,
    String? soldToUid,
    String? paymentMethod,
    String? paymentReference,
    DateTime? soldAt,
    String? confirmedByAdminUid,
    String? usedByUid,
    DateTime? usedAt,
  }) =>
      VoucherModel(
        id: id ?? this.id,
        code: code ?? this.code,
        examType: examType ?? this.examType,
        price: price ?? this.price,
        status: status ?? this.status,
        generatedByAdminUid:
        generatedByAdminUid ?? this.generatedByAdminUid,
        createdAt: createdAt ?? this.createdAt,
        soldToUid: soldToUid ?? this.soldToUid,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentReference:
        paymentReference ?? this.paymentReference,
        soldAt: soldAt ?? this.soldAt,
        confirmedByAdminUid:
        confirmedByAdminUid ?? this.confirmedByAdminUid,
        usedByUid: usedByUid ?? this.usedByUid,
        usedAt: usedAt ?? this.usedAt,
      );
}