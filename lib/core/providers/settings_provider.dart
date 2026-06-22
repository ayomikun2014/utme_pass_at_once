import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_settings_model.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();

  AppSettingsModel _settings = AppSettingsModel.initial();
  AppSettingsModel get settings => _settings;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _installedVersion = '1.0.0';
  String get installedVersion => _installedVersion;

  StreamSubscription<AppSettingsModel>? _subscription;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _installedVersion = packageInfo.version;

      _settings = await _service.fetchSettings();

      debugPrint(
        '✅ Settings loaded: phones=${_settings.supportPhones.length}, email=${_settings.contactEmail}, whatsapp=${_settings.whatsappNumber}',
      );

      _subscription?.cancel();
      _subscription = _service.watchSettings().listen(
            (updatedSettings) {
          _settings = updatedSettings;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('⚠️ SettingsProvider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadSettings();
  }

  // ── Pricing
  int get jambPrice => _settings.jambPrice;
  int get waecPrice => _settings.waecPrice;
  int get necoPrice => _settings.necoPrice;
  int get postUtmePrice => _settings.postUtmePrice;

  // ── Payment Control
  bool get paymentGatewayEnabled => _settings.paymentGatewayEnabled;

  // ── Bank and Contact
  List<BankDetail> get bankDetails => _settings.bankDetails;
  String get contactEmail => _settings.contactEmail;
  List<PhoneDetail> get supportPhones => _settings.supportPhones;

  PhoneDetail? get primaryPhone {
    if (_settings.supportPhones.isEmpty) return null;

    return _settings.supportPhones.firstWhere(
          (phone) => phone.isPrimary,
      orElse: () => _settings.supportPhones.first,
    );
  }

  String get whatsappNumber => _settings.whatsappNumber;

  // ── Links
  String get playStoreUrl => _settings.playStoreUrl;
  String get appStoreUrl => _settings.appStoreUrl;
  String get shareLink => _settings.shareLink;

  // ── System and Versioning
  bool get maintenanceMode => _settings.maintenanceMode;
  String get latestAppVersion => _settings.latestAppVersion; // RENAMED
  String get minAppVersion => _settings.minAppVersion;
  bool get forceUpdate => _settings.forceUpdate;
  bool get showUpdatePrompt => _settings.showUpdatePrompt; // ADDED
  String get updateTitle => _settings.updateTitle;
  String get updateMessage => _settings.updateMessage;
  String get androidUpdateUrl => _settings.androidUpdateUrl;
  String get iosUpdateUrl => _settings.iosUpdateUrl;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}