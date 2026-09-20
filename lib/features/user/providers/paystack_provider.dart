import 'package:flutter/material.dart';
import '../services/paystack_service.dart';
import '../../../core/services/network_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaystackService _paystackService = PaystackService.instance;

  bool _isLoading = false;
  String _errorMessage = '';
  String? _lastReference;
  String? _authorizationUrl;
  String? _voucherCode;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String? get lastReference => _lastReference;
  String? get authorizationUrl => _authorizationUrl;
  String? get voucherCode => _voucherCode;

  Future<bool> initializeCheckout({
    required String email,
    required double amount,
    required String examType,
    required String uid,
    String? userName,
  }) async {
    _setLoading(true);
    _errorMessage = '';
    _lastReference = null;
    _authorizationUrl = null;
    _voucherCode = null;

    if (!await _checkConnection()) return false;

    try {
      final int amountKobo = (amount * 100).round();

      final transactionData = await _paystackService.initializeTransaction(
        email: email,
        amount: amountKobo,
        examType: examType,
        uid: uid,
        name: userName,
      );

      _authorizationUrl = transactionData['authorization_url'] as String?;
      _lastReference = transactionData['reference'] as String?;

      _setLoading(false);
      return _authorizationUrl != null && _lastReference != null;
    } catch (e) {
      _errorMessage = await _friendlyError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyCompletedPayment(String reference) async {
    _errorMessage = '';

    for (int attempt = 1; attempt <= 5; attempt++) {
      _setLoading(true);

      if (!await _checkConnection()) {
        _setLoading(false);
        return false;
      }

      try {
        debugPrint('Checking payment verification, attempt $attempt/5...');
        final result = await _paystackService.verifyTransaction(
          reference: reference,
        );

        final paymentStatus = result['paymentStatus'] as String?;
        final code = result['voucherCode'] as String?;

        if (paymentStatus == 'success' && code != null && code.trim().isNotEmpty) {
          _voucherCode = code;
          _setLoading(false);
          return true;
        }

        if (paymentStatus == 'pending' || paymentStatus == 'abandoned' || paymentStatus == 'processing') {
          if (attempt == 5) {
            _errorMessage = 'Payment is still processing. Please check your order history shortly.';
            _setLoading(false);
            return false;
          }
          debugPrint('Payment is $paymentStatus. Retrying in 3 seconds...');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        _voucherCode = code;
        _setLoading(false);
        return true;
      } catch (e) {
        if (attempt == 5) {
          _errorMessage = await _friendlyError(e);
          _setLoading(false);
          return false;
        }
        debugPrint('Verification failed with error: $e. Retrying in 3 seconds...');
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    _setLoading(false);
    return false;
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> _checkConnection() async {
    final isOnline = await NetworkService.instance.hasInternet();
    if (!isOnline) {
      _errorMessage = 'No internet connection. Please check your network and try again.';
      _setLoading(false);
      return false;
    }
    return true;
  }

  /// Converts raw exceptions into short, user-friendly messages.
  Future<String> _friendlyError(Object e) async {
    final hasInternet = await NetworkService.instance.hasInternet();
    if (!hasInternet) {
      return 'No internet connection. Please check your network and try again.';
    }

    final msg = e.toString();

    // Check for HTTP / socket / Cloud Run / closed billing indicators
    if (msg.contains('ClientException') ||
        msg.contains('Failed to fetch') ||
        msg.contains('503') ||
        msg.contains('403') ||
        msg.contains('404') ||
        msg.contains('Html') ||
        msg.contains('parser') ||
        msg.contains('Connection refused') ||
        msg.contains('SocketException') ||
        msg.contains('TimeoutException') ||
        msg.contains('unavailable') ||
        msg.contains('deadline')) {
      return 'This service is currently unavailable. Please try again later or contact our support team.';
    }

    return msg.replaceFirst('Exception: ', '').replaceFirst('FirebaseException: ', '');
  }
}