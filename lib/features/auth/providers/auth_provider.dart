import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW: Required for _firestore
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Required for providerData checks
import '../../../core/utils/device_helper.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../../user/services/simulator_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/network_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // NEW: Initialize the Firestore object for the updateProfile method
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  String _currentDeviceId = '';
  bool _isLoading = false;
  String _errorMessage = '';

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  String get currentDeviceId => _currentDeviceId;

  /// Check if the current user logged in with Google
  bool get isGoogleUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  /// Check if the current user has premium access for a specific exam
  /// bound to THIS device's hardware ID.
  bool hasPremiumAccessFor(String examName) {
    if (_currentUser == null || _currentDeviceId.isEmpty) return false;
    return _currentUser!.hasActiveExam(examName, _currentDeviceId);
  }

  /// Check if user has premium for this exam on ANY device
  bool hasPremiumAnyDevice(String examName) {
    if (_currentUser == null) return false;
    return _currentUser!.isPremiumForExamAnyDevice(examName);
  }

  // ---------------------------------------------------------------------------
  // CONSTRUCTOR — initialise device ID immediately
  // ---------------------------------------------------------------------------
  AuthProvider() {
    _initializeDevice();
    NotificationService.instance.initialize();
  }

  Future<void> _initializeDevice() async {
    _currentDeviceId = await DeviceHelper.getDeviceId();
    debugPrint('📱 Device ID initialized: $_currentDeviceId');
  }

  /// Ensures the device ID is ready before performing any premium checks.
  Future<void> _ensureDeviceId() async {
    if (_currentDeviceId.isEmpty) {
      _currentDeviceId = await DeviceHelper.getDeviceId();
    }
  }

  // ---------------------------------------------------------------------------
  // AUTO-LOGIN (called from AuthGate on app startup)
  // ---------------------------------------------------------------------------
  Future<bool> tryAutoLogin() async {
    try {
      // CRITICAL: Wait for device ID before loading user data
      await _ensureDeviceId();

      _currentUser = await _authService.tryAutoLogin();
      if (_currentUser != null) {
        NotificationService.instance.initialize();
        NotificationService.instance.registerToken(_currentUser!.uid);

        // MIGRATION: If user's stored deviceId doesn't match the new computed one,
        // update Firestore so their premium access continues working after the
        // DeviceHelper fix (old code used androidInfo.id which was just a build string).
        await _migrateDeviceIdIfNeeded();

        // Download free aptitude offline questions in the background
        SimulatorService().predownloadFreeAptitudeQuestions();

        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      // Silently fail — user will see login screen
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // EMAIL LOGIN
  // ---------------------------------------------------------------------------
  Future<bool> login(String email, String password) async {
    _clearError();
    _setLoading(true);
    if (!await _checkConnection()) return false;
    await _ensureDeviceId();
    try {
      _currentUser = await _authService.login(email, password);
      if (_currentUser != null) {
        NotificationService.instance.registerToken(_currentUser!.uid);
        // Download free aptitude offline questions in the background
        SimulatorService().predownloadFreeAptitudeQuestions();
      } else {
        _errorMessage = 'User profile data is missing. Please sign up again or contact support.';
      }
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // EMAIL SIGN UP
  // ---------------------------------------------------------------------------
  Future<bool> signUp(
      String email, String password, String name, String phone) async {
    _clearError();
    _setLoading(true);
    if (!await _checkConnection()) return false;
    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        fullName: name,
        phone: phone,
      );
      if (_currentUser != null) {
        NotificationService.instance.registerToken(_currentUser!.uid);
        // Download free aptitude offline questions in the background
        SimulatorService().predownloadFreeAptitudeQuestions();
      } else {
        _errorMessage = 'Failed to create user profile. Please try again.';
      }
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ---------------------------------------------------------------------------
  Future<bool> googleSignIn() async {
    _clearError();
    _setLoading(true);
    if (!await _checkConnection()) return false;
    try {
      _currentUser = await _authService.signInWithGoogle();
      if (_currentUser != null) {
        NotificationService.instance.registerToken(_currentUser!.uid);
        // Download free aptitude offline questions in the background
        SimulatorService().predownloadFreeAptitudeQuestions();
      } else {
        _errorMessage = 'User profile data is missing. Please sign up again or contact support.';
      }
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SEND PASSWORD RESET EMAIL
  // ---------------------------------------------------------------------------
  Future<bool> sendPasswordResetEmail(String email) async {
    _clearError();
    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CHANGE PASSWORD
  // ---------------------------------------------------------------------------
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    _clearError();
    _setLoading(true);
    try {
      await _authService.changePassword(currentPassword, newPassword);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE ACCOUNT
  // ---------------------------------------------------------------------------
  Future<bool> deleteAccount({String? password}) async {
    _clearError();
    _setLoading(true);
    try {
      await _authService.deleteAccount(password: password);
      _currentUser = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

// ---------------------------------------------------------------------------
  // UPDATE PROFILE (Offline-Resilient Version)
  // ---------------------------------------------------------------------------
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    try {
      if (_currentUser == null) return false;

      // 1. OPTIMISTIC UPDATE: Apply changes to the in-memory model immediately
      //    This ensures the UI updates instantly even when offline.
      final currentData = _currentUser!.toMap();
      final mergedData = Map<String, dynamic>.from(currentData)..addAll(updates);
      // FieldValue.serverTimestamp() can't be deserialized by fromMap() —
      // replace with the current DateTime so the model can be reconstructed.
      mergedData['createdAt'] = Timestamp.fromDate(_currentUser!.createdAt);
      _currentUser = UserModel.fromMap(mergedData, _currentUser!.uid);
      notifyListeners();

      // 2. BACKGROUND SYNC: Send update to Firestore.
      //    Firestore SDK will queue this write locally and sync when online.
      _firestore.collection('users').doc(_currentUser!.uid).update(updates).catchError((e) {
        debugPrint('⚠️ [PROFILE] Background Firestore sync failed: $e');
        // The local Firestore cache still has the pending write,
        // it will retry automatically when connectivity returns.
      });

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('❌ [PROFILE] updateProfile error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH USER (pull-to-refresh & background sync)
  // ---------------------------------------------------------------------------
  Future<void> refreshUser() async {
    try {
      debugPrint("⏳ DEBUG: Fetching fresh user profile from Firestore...");

      _currentUser = await _authService.forceRefreshUser();
      notifyListeners();

      debugPrint("✅ DEBUG: Fresh user fetched successfully!");
      debugPrint("✅ DEBUG: Downloaded Selections: ${_currentUser?.examSelections}");

    } catch (e) {
      // If this prints, your Hive adapter or Firestore read is crashing!
      debugPrint("💥 DEBUG: FAILED TO REFRESH USER: $e");
      if (e.toString().contains('suspended by the admin')) {
        _currentUser = null;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
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

  // ---------------------------------------------------------------------------
  // DEVICE ID MIGRATION (one-time, after DeviceHelper fix)
  // ---------------------------------------------------------------------------
  /// Updates the deviceId in Firestore if it doesn't match the new computed ID.
  /// This handles the transition from the old broken `androidInfo.id` (build string)
  /// to the new composite hardware fingerprint.
  Future<void> _migrateDeviceIdIfNeeded() async {
    if (_currentUser == null || _currentDeviceId.isEmpty) return;

    final storedDeviceId = _currentUser!.deviceId;

    // If deviceId already matches, no migration needed
    if (storedDeviceId == _currentDeviceId) return;

    // If user has no premium access at all, just update the top-level deviceId
    if (!_currentUser!.isPremium) {
      debugPrint('📱 [MIGRATION] Non-premium user, updating deviceId only');
      _firestore.collection('users').doc(_currentUser!.uid).update({
        'deviceId': _currentDeviceId,
      }).catchError((e) {
        debugPrint('⚠️ [MIGRATION] Failed to update deviceId: $e');
      });
      return;
    }

    debugPrint('📱 [MIGRATION] Device ID mismatch detected!');
    debugPrint('📱 [MIGRATION] Old: $storedDeviceId → New: $_currentDeviceId');
    debugPrint('📱 [MIGRATION] Updating Firestore records...');

    try {
      // Build the update map for all exam selections
      final Map<String, dynamic> updates = {
        'deviceId': _currentDeviceId,
      };

      // Update the deviceId inside each examSelection entry
      final selections = _currentUser!.examSelections;
      for (final examType in selections.keys) {
        final selection = selections[examType];
        if (selection is Map && selection.containsKey('deviceId')) {
          updates['examSelections.$examType.deviceId'] = _currentDeviceId;
        }
      }

      await _firestore.collection('users').doc(_currentUser!.uid).update(updates);

      // Refresh user model so in-memory data reflects the new ID
      _currentUser = await _authService.forceRefreshUser();

      debugPrint('✅ [MIGRATION] Device ID migration complete!');
    } catch (e) {
      debugPrint('⚠️ [MIGRATION] Error during device ID migration: $e');
      // Non-fatal — the user can still use the app, just might see
      // "different device" dialog until next successful migration
    }
  }
}