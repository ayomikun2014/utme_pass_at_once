import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'app_settings';
  static const String _docId = 'general';
  static const String _cacheKey = 'cached_app_settings';

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(_collection).doc(_docId);

  Future<AppSettingsModel> fetchSettings() async {
    final cachedSettings = await _getCachedSettings();

    try {
      debugPrint('🔍 Fetching app settings from Firestore...');

      final doc = await _ref.get().timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        debugPrint('⚠️ App settings document not found');
        return cachedSettings ?? AppSettingsModel.initial();
      }

      final data = doc.data()!;
      debugPrint('✅ App settings received: ${data.keys.toList()}');

      final settings = AppSettingsModel.fromMap(data);

      await _cacheSettings(settings);

      return settings;
    } on TimeoutException {
      debugPrint('⚠️ App settings fetch timeout');
      return cachedSettings ?? AppSettingsModel.initial();
    } catch (e) {
      debugPrint('⚠️ App settings fetch failed: $e');
      return cachedSettings ?? AppSettingsModel.initial();
    }
  }

  Stream<AppSettingsModel> watchSettings() {
    return _ref
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists || doc.data() == null) {
        return AppSettingsModel.initial();
      }

      final data = doc.data()!;
      final settings = AppSettingsModel.fromMap(data);

      await _cacheSettings(settings);

      return settings;
    })
        .handleError((error) {
      debugPrint('⚠️ App settings stream error: $error');
    });
  }

  Future<AppSettingsModel?> _getCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson == null || cachedJson.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(cachedJson);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return AppSettingsModel.fromMap(decoded);
    } catch (e) {
      debugPrint('⚠️ App settings cache read failed: $e');
      return null;
    }
  }

  Future<void> _cacheSettings(AppSettingsModel settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(_settingsToCacheMap(settings)),
      );
    } catch (e) {
      debugPrint('⚠️ App settings cache save failed: $e');
    }
  }

  // FIXED: Updated to match the new AppSettingsModel fields!
  Map<String, dynamic> _settingsToCacheMap(AppSettingsModel settings) {
    return {
      'maintenanceMode': settings.maintenanceMode,
      'paymentGatewayEnabled': settings.paymentGatewayEnabled, // NEW

      'latestAppVersion': settings.latestAppVersion, // RENAMED
      'minAppVersion': settings.minAppVersion,
      'forceUpdate': settings.forceUpdate,
      'showUpdatePrompt': settings.showUpdatePrompt, // NEW
      'updateTitle': settings.updateTitle,
      'updateMessage': settings.updateMessage,
      'androidUpdateUrl': settings.androidUpdateUrl,
      'iosUpdateUrl': settings.iosUpdateUrl,

      'jambPrice': settings.jambPrice,
      'waecPrice': settings.waecPrice,
      'necoPrice': settings.necoPrice,
      'postUtmePrice': settings.postUtmePrice,

      // Cached with the rest, otherwise an offline read falls back to the
      // built-in defaults and the store forgets what the admin put on sale.
      'jambOnSale': settings.jambOnSale,
      'waecOnSale': settings.waecOnSale,
      'necoOnSale': settings.necoOnSale,
      'postUtmeOnSale': settings.postUtmeOnSale,

      'bankDetails': settings.bankDetails.map((b) => b.toMap()).toList(),

      'contactEmail': settings.contactEmail,
      'supportPhones': settings.supportPhones.map((p) => p.toMap()).toList(),
      'whatsappNumber': settings.whatsappNumber,

      'playStoreUrl': settings.playStoreUrl,
      'appStoreUrl': settings.appStoreUrl,
      'shareLink': settings.shareLink,

      'updatedAt': settings.updatedAt?.toIso8601String(),
    };
  }
}