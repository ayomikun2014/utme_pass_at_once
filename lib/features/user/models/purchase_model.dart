import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseModel {
  final String id;
  final String uid;
  final String userName;
  final String email;
  final String examType;
  final double amount;
  final int amountKobo;
  final String currency;
  final String paymentMethod;
  final String paystackReference;
  final String status;
  final String verificationStatus;
  final String? voucherCode;
  final String? channel;
  final String? gatewayResponse;
  final String? errorMessage;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;

  final bool? hiddenByUser;
  final DateTime? userHiddenAt;
  final String? userHiddenByUid;

  const PurchaseModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.email,
    required this.examType,
    required this.amount,
    required this.amountKobo,
    required this.currency,
    required this.paymentMethod,
    required this.paystackReference,
    required this.status,
    this.verificationStatus = 'pending',
    this.voucherCode,
    this.channel,
    this.gatewayResponse,
    this.errorMessage,
    this.failureReason,
    required this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.hiddenByUser,
    this.userHiddenAt,
    this.userHiddenByUid,
  });

  factory PurchaseModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    final int amountKobo =
        (data['amountKobo'] as num?)?.toInt() ??
            (data['expectedAmount'] as num?)?.toInt() ??
            (((data['amount'] as num?)?.toDouble() ?? 0.0) * 100).round();

    final double amountNaira =
        (data['amount'] as num?)?.toDouble() ?? (amountKobo / 100);

    return PurchaseModel(
      id: id,
      uid: (data['uid'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      examType: (data['examType'] ?? '').toString(),
      amount: amountNaira,
      amountKobo: amountKobo,
      currency: (data['currency'] ?? 'NGN').toString(),
      paymentMethod: (data['paymentMethod'] ?? 'paystack').toString(),
      paystackReference:
      (data['paystackReference'] ?? data['reference'] ?? '').toString(),
      status: (data['status'] ?? 'unknown').toString(),
      verificationStatus: (data['verificationStatus'] ?? data['status'] ?? 'pending').toString(),
      voucherCode: data['voucherCode'] as String?,
      channel: data['channel'] as String?,
      gatewayResponse: data['gatewayResponse'] as String?,
      errorMessage: data['errorMessage'] as String?,
      failureReason: data['failureReason'] as String?,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(data['updatedAt']),
      paidAt: parseDate(data['paidAt']),
      hiddenByUser: data['hiddenByUser'] as bool?,
      userHiddenAt: parseDate(data['userHiddenAt']),
      userHiddenByUid: data['userHiddenByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'userName': userName,
      'email': email,
      'examType': examType,
      'amount': amount,
      'amountKobo': amountKobo,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'paystackReference': paystackReference,
      'status': status,
      'verificationStatus': verificationStatus,
      if (voucherCode != null) 'voucherCode': voucherCode,
      if (channel != null) 'channel': channel,
      if (gatewayResponse != null) 'gatewayResponse': gatewayResponse,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (failureReason != null) 'failureReason': failureReason,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      if (hiddenByUser != null) 'hiddenByUser': hiddenByUser,
      if (userHiddenAt != null) 'userHiddenAt': Timestamp.fromDate(userHiddenAt!),
      if (userHiddenByUid != null) 'userHiddenByUid': userHiddenByUid,
    };
  }

  PurchaseModel copyWith({
    String? id,
    String? uid,
    String? userName,
    String? email,
    String? examType,
    double? amount,
    int? amountKobo,
    String? currency,
    String? paymentMethod,
    String? paystackReference,
    String? status,
    String? verificationStatus,
    String? voucherCode,
    String? channel,
    String? gatewayResponse,
    String? errorMessage,
    String? failureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    bool? hiddenByUser,
    DateTime? userHiddenAt,
    String? userHiddenByUid,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      examType: examType ?? this.examType,
      amount: amount ?? this.amount,
      amountKobo: amountKobo ?? this.amountKobo,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paystackReference: paystackReference ?? this.paystackReference,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      voucherCode: voucherCode ?? this.voucherCode,
      channel: channel ?? this.channel,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
      errorMessage: errorMessage ?? this.errorMessage,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      hiddenByUser: hiddenByUser ?? this.hiddenByUser,
      userHiddenAt: userHiddenAt ?? this.userHiddenAt,
      userHiddenByUid: userHiddenByUid ?? this.userHiddenByUid,
    );
  }

  bool get isInitialized => status == 'initialized' || status == 'pending';
  bool get isVerifying => status == 'verifying';
  bool get isVerified => status == 'verified' || status == 'completed' || status == 'success';
  bool get isVoucherGenerated =>
      status == 'code_generated' ||
      status == 'voucher_generated' ||
      status == 'approved' ||
      status == 'success' ||
      status == 'completed';
  bool get isPaymentFailed => status == 'failed' || isCancelled;
  bool get isCancelled => status == 'cancelled';
  bool get isUsed => status == 'used';

  bool get isPending =>
      !isPaymentFailed &&
      !isVoucherGenerated &&
      !isUsed &&
      (isInitialized ||
          isVerifying ||
          verificationStatus == 'pending' ||
          verificationStatus == 'processing' ||
          status == 'pending');

  bool get hasVoucher => (voucherCode ?? '').trim().isNotEmpty;
  bool get canCopyVoucher => hasVoucher && (isVoucherGenerated || isUsed);
  bool get canUnlock => hasVoucher && !isUsed;

  bool get showPendingMessage => isPending;

  /// A payment still waiting on the buyer or on an admin can be called off, so
  /// the buyer is free to start a fresh one. Once a code exists there is
  /// nothing to cancel.
  bool get canCancel => isPending && !hasVoucher && !isUsed && !isCancelled;

  bool get showFailureMessage =>
      isPaymentFailed ||
          status == 'code_generation_failed' ||
          (failureReason != null && failureReason!.trim().isNotEmpty) ||
          (errorMessage != null && errorMessage!.trim().isNotEmpty);

  String get effectiveMessage {
    if (isCancelled) {
      return 'You cancelled this payment. You can start a new one whenever you are ready.';
    }
    if (failureReason != null && failureReason!.trim().isNotEmpty) {
      return failureReason!;
    }
    if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      return errorMessage!;
    }
    if (isPending) {
      return 'Your payment is still being processed. Please refresh shortly or make a new payment if this one was not completed.';
    }
    if (isVerified && !hasVoucher) {
      return 'Payment verified successfully. Voucher generation is still in progress.';
    }
    if (isVoucherGenerated) {
      return 'Your activation code is ready.';
    }
    if (isUsed) {
      return 'This activation code has already been used.';
    }
    if (isPaymentFailed) {
      return 'This transaction did not complete successfully.';
    }
    return 'Transaction status available.';
  }

  String get statusLabel {
    if (isCancelled) return 'Cancelled';
    if (isUsed) return 'Used';
    if (isVoucherGenerated) return 'Code Ready';
    if (isVerified && !hasVoucher) return 'Generating Code';
    if (isVerifying) return 'Verifying';
    if (isInitialized || status == 'pending') return 'Pending';
    if (status == 'code_generation_failed') return 'Code Failed';
    if (isPaymentFailed) return 'Failed';
    return 'Pending';
  }

  String get supportActionLabel {
    if (status == 'code_generation_failed') return 'Contact Support';
    if (isPaymentFailed) return 'Contact Support';
    return 'Get Help';
  }
}