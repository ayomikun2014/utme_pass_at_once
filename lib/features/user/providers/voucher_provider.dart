import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/network_helper.dart';
import '../models/purchase_model.dart';
import '../services/voucher_service.dart';

class VoucherProvider extends ChangeNotifier {
  final VoucherService _voucherService = VoucherService();

  bool _isLoading = false;
  String _errorMessage = '';
  List<PurchaseModel> _cachedPurchases = [];

  static const String _purchasesCacheKey = 'cached_purchases';

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<PurchaseModel> get purchases => _cachedPurchases;

  Future<List<PurchaseModel>> fetchUserPurchases(String uid) async {
    _setLoading(true);
    _errorMessage = '';

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('${_purchasesCacheKey}_$uid');

      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);

        _cachedPurchases = decoded.map((e) {
          final map = Map<String, dynamic>.from(e);
          return PurchaseModel.fromMap(map, map['id'] ?? '');
        }).toList();
      }
    } catch (_) {}

    try {
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        if (_cachedPurchases.isNotEmpty) {
          _setLoading(false);
          return _cachedPurchases;
        }
        throw Exception('No internet connection.');
      }

      final list = await _voucherService.fetchUserPurchases(uid);
      _cachedPurchases = list;

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(list.map((e) => e.toMap()).toList());

      await prefs.setString('${_purchasesCacheKey}_$uid', jsonStr);

      _setLoading(false);
      return list;
    } catch (e) {
      _setLoading(false);

      if (_cachedPurchases.isNotEmpty) {
        return _cachedPurchases;
      }

      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return [];
    }
  }

  Future<bool> hideUserPurchase({
    required String transactionId,
    required String uid,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    try {
      await _voucherService.hideUserPurchase(
        transactionId: transactionId,
        uid: uid,
      );

      _cachedPurchases.removeWhere((item) => item.id == transactionId);

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_cachedPurchases.map((e) => e.toMap()).toList());
      await prefs.setString('${_purchasesCacheKey}_$uid', jsonStr);

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}