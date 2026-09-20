import 'dart:typed_data';
import 'package:flutter/material.dart';

// Import your service here
import '../services/manual_payment_service.dart';
import '../../../core/services/network_service.dart';

class ManualPaymentProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<bool> submitPayment({
    required String uid,
    required String email,
    required String userName,
    required double amount,
    required String examType,
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      await ManualPaymentService.instance.submitManualPayment(
        uid: uid,
        email: email,
        userName: userName,
        amount: amount,
        examType: examType,
        imageBytes: imageBytes,
        imageExtension: imageExtension,
      );

      _isLoading = false;
      notifyListeners();
      return true; // Success!

    } catch (e) {
      _errorMessage = await _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false; // Failed
    }
  }

  /// Converts raw exceptions (especially storage/network ones) into short,
  /// user-friendly messages.
  Future<String> _friendlyError(Object e) async {
    final hasInternet = await NetworkService.instance.hasInternet();
    if (!hasInternet) {
      return 'No internet connection. Please check your network and try again.';
    }

    final msg = e.toString();

    // Check for network, socket, storage quota, permission, or closed billing indicators
    if (msg.contains('unavailable') ||
        msg.contains('deadline') ||
        msg.contains('quota') ||
        msg.contains('SocketException') ||
        msg.contains('TimeoutException') ||
        msg.contains('Connection refused') ||
        msg.contains('ClientException') ||
        msg.contains('Failed to fetch') ||
        msg.contains('503') ||
        msg.contains('403') ||
        msg.contains('404') ||
        msg.contains('unauthorized') ||
        msg.contains('permission-denied')) {
      return 'This service is currently unavailable. Please try again later or contact our support team.';
    }

    return msg.replaceAll('Exception: ', '').replaceAll('FirebaseException: ', '');
  }
}