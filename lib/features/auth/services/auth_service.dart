import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/hive_setup.dart';
import '../models/local_user.dart';
import 'package:utme_pass_at_once/features/auth/models/user_model.dart';
import 'package:utme_pass_at_once/core/utils/device_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _refreshKey = 'needsFirestoreRefresh';

  void _markNeedsRefresh() =>
      Hive.box(HiveSetup.settingsBoxName).put(_refreshKey, true);
  bool _shouldRefreshFromFirestore() =>
      Hive.box(HiveSetup.settingsBoxName).get(_refreshKey, defaultValue: true)
          as bool;
  void _clearRefreshFlag() =>
      Hive.box(HiveSetup.settingsBoxName).put(_refreshKey, false);

  // ---------------------------------------------------------------------------
  // 1. EMAIL & PASSWORD SIGN UP
  // ---------------------------------------------------------------------------
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        try {
          return await _createNewUserRecord(cred.user!, email, fullName, phone);
        } catch (e, stackTrace) {
          debugPrint('Firestore Profile Creation Error: $e\n$stackTrace');
          try {
            await cred.user!.delete();
          } catch (rollbackError) {
            debugPrint('Rollback Deletion Error: $rollbackError');
          }
          throw Exception(
            'Network dropped before saving profile. Please try signing up again.',
          );
        }
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'SignUp FirebaseAuthException [${e.code}]: ${e.message}\n$stackTrace',
      );
      throw Exception(_handleAuthError(e.code));
    } catch (e, stackTrace) {
      debugPrint('SignUp General Exception: $e\n$stackTrace');
      throw Exception(
        'An unexpected error occurred. Please check your connection.',
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. EMAIL & PASSWORD LOGIN
  // ---------------------------------------------------------------------------
  Future<UserModel?> login(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        // Update last login
        try {
          await _firestore.collection('users').doc(cred.user!.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        UserModel? user = await _fetchAndCacheUser(cred.user!.uid);
        if (user != null) {
          await _checkSuspension(user);
        }

        return user ??
            await _createNewUserRecord(
              cred.user!,
              cred.user!.email ?? email,
              cred.user!.displayName ?? 'Student',
              '',
            );
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'Login FirebaseAuthException [${e.code}]: ${e.message}\n$stackTrace',
      );
      throw Exception(_handleAuthError(e.code));
    } catch (e, stackTrace) {
      debugPrint('Login General Exception: $e\n$stackTrace');
      if (e.toString().contains('suspended by the admin') ||
          e.toString().contains('locked to another device')) {
        rethrow;
      }
      throw Exception('An unexpected error occurred during login.');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 3. GOOGLE SIGN-IN (Fixed for v7.2.0+)
  // ---------------------------------------------------------------------------
  Future<UserModel?> signInWithGoogle() async {
    try {
      User? firebaseUser;
      String? defaultEmail;
      String? defaultName;

      if (kIsWeb) {
        // NATIVE FIREBASE WEB APPROACH
        final googleProvider = GoogleAuthProvider();
        final cred = await _auth.signInWithPopup(googleProvider);
        firebaseUser = cred.user;
      } else {
        // MOBILE GOOGLE SIGN IN APPROACH (v7.2.0+)

        // FORCE CACHE CLEAR: Prevents the "stale ID token" error
        await GoogleSignIn.instance.signOut();

        // 1. Identity: Trigger the new system-level account picker
        //    In v7.2.0+, authenticate() throws on cancellation (non-nullable return).
        late final GoogleSignInAccount googleUser;
        try {
          googleUser = await GoogleSignIn.instance.authenticate();
        } catch (e) {
          debugPrint('Google Sign-In was cancelled by the user: $e');
          return null;
        }

        // 2. Authentication: Get the ID Token (synchronous getter in v7.x)
        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception(
            'Google Sign-In failed securely: No ID Token generated.',
          );
        }

        // 3. Authorization: Explicitly request the Access Token
        final authClient = await googleUser.authorizationClient.authorizeScopes(
          ['email', 'profile'],
        );
        final accessToken = authClient.accessToken;

        // 4. Create the Firebase Credential using the separated tokens
        final credential = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );

        final cred = await _auth.signInWithCredential(credential);
        firebaseUser = cred.user;
        defaultEmail = googleUser.email;
        defaultName = googleUser.displayName;
      }

      if (firebaseUser == null) {
        throw Exception('Authentication failed securely.');
      }

      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        try {
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
        final user = await _fetchAndCacheUser(firebaseUser.uid);
        if (user != null) {
          await _checkSuspension(user);
        }
        return user;
      }

      return await _createNewUserRecord(
        firebaseUser,
        firebaseUser.email ?? defaultEmail ?? 'No Email',
        firebaseUser.displayName ?? defaultName ?? 'New Student',
        '',
      );
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'Google Sign-In FirebaseAuthException [${e.code}]: ${e.message}\n$stackTrace',
      );
      throw Exception(_handleAuthError(e.code, isGoogle: true));
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In General Exception: $e\n$stackTrace');
      if (e.toString().contains('suspended by the admin') ||
          e.toString().contains('locked to another device')) {
        rethrow;
      }
      throw Exception('Google Sign-In Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // OTHER AUTH METHODS
  // ---------------------------------------------------------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('Password Reset Error [${e.code}]: ${e.message}\n$stackTrace');
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Session expired.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'Change Password Error [${e.code}]: ${e.message}\n$stackTrace',
      );
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Current password is incorrect.');
      }
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<void> deleteAccount({String? password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Session expired.');
      }

      // Check if user is Google user
      bool isGoogleUser = false;
      for (final providerInfo in user.providerData) {
        if (providerInfo.providerId == 'google.com') {
          isGoogleUser = true;
          break;
        }
      }

      if (isGoogleUser) {
        // Reauthenticate with Google
        await GoogleSignIn.instance.signOut(); // Force cache clear to ensure fresh picker
        late final GoogleSignInAccount googleUser;
        try {
          googleUser = await GoogleSignIn.instance.authenticate();
        } catch (e) {
          debugPrint('Google Re-auth was cancelled by the user: $e');
          throw Exception('Google re-authentication was cancelled.');
        }

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception('Google Re-auth failed securely: No ID Token generated.');
        }

        final authClient = await googleUser.authorizationClient.authorizeScopes(
          ['email', 'profile'],
        );
        final accessToken = authClient.accessToken;

        final credential = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );

        await user.reauthenticateWithCredential(credential);
      } else {
        if (password == null || password.isEmpty) {
          throw Exception('Password is required to delete account.');
        }
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // --- COMPLETE FIRESTORE CLEANUP ---
      // Delete Firestore data before deleting the Firebase Auth user to avoid security rule errors.
      final userRef = _firestore.collection('users').doc(user.uid);

      final subcollectionNames = [
        'exam_history',
        'notifications',
        'payment_rate_limits',
        'fcmTokens',
      ];

      final List<Future<void>> deleteFutures = [];

      for (final subName in subcollectionNames) {
        deleteFutures.add(() async {
          try {
            final snap = await userRef.collection(subName).get();
            if (snap.docs.isNotEmpty) {
              final batch = _firestore.batch();
              for (var doc in snap.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
            }
          } catch (e) {
            debugPrint("Failed to delete subcollection $subName during self-delete: $e");
          }
        }());
      }

      // Wait for all subcollection cleanups to complete
      await Future.wait(deleteFutures);

      // Finally, delete the top-level user document
      await userRef.delete();

      // Clear local Hive cache
      await Hive.box<LocalUser>(HiveSetup.userBoxName).clear();

      // Delete Firebase Auth user
      await user.delete();
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('Delete Account Error [${e.code}]: ${e.message}\n$stackTrace');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password.');
      }
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google Sign Out Error (Silent Fail): $e');
    }
    await _auth.signOut();
    await Hive.box<LocalUser>(HiveSetup.userBoxName).clear();
    _markNeedsRefresh();
  }

  Future<UserModel?> tryAutoLogin() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    if (!_shouldRefreshFromFirestore()) {
      final cached = _getUserFromCache();
      if (cached != null) return cached;
    }
    try {
      final freshUser = await _fetchAndCacheUser(user.uid);
      if (freshUser != null) {
        await _checkSuspension(freshUser);
      }
      _clearRefreshFlag();
      return freshUser;
    } catch (e, stackTrace) {
      debugPrint('Auto Login Refresh Error: $e\n$stackTrace');
      if (e.toString().contains('suspended by the admin') ||
          e.toString().contains('locked to another device')) {
        rethrow;
      }
      return _getUserFromCache();
    }
  }

  Future<UserModel?> forceRefreshUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final fresh = await _fetchAndCacheUser(user.uid);
      if (fresh != null) {
        await _checkSuspension(fresh);
      }
      _clearRefreshFlag();
      return fresh;
    } catch (e, stackTrace) {
      debugPrint('Force Refresh Error: $e\n$stackTrace');
      if (e.toString().contains('suspended by the admin') ||
          e.toString().contains('locked to another device')) {
        rethrow;
      }
      return _getUserFromCache();
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Future<void> _checkSuspension(UserModel user) async {
    if (!user.isActive) {
      await _auth.signOut();
      await Hive.box<LocalUser>(HiveSetup.userBoxName).clear();

      String contactEmail = 'taiwoprints999@gmail.com';
      String whatsappNumber = '';

      try {
        final settingsDoc = await _firestore
            .collection('app_settings')
            .doc('general')
            .get()
            .timeout(const Duration(seconds: 5));
        if (settingsDoc.exists) {
          contactEmail = settingsDoc.data()?['contactEmail'] ?? contactEmail;
          whatsappNumber = settingsDoc.data()?['whatsappNumber'] ?? '';
        }
      } catch (_) {}

      final msg = whatsappNumber.isNotEmpty
          ? 'Your account has been suspended by the admin.\nPlease contact us for more information at $contactEmail or WhatsApp: $whatsappNumber.'
          : 'Your account has been suspended by the admin.\nPlease contact us for more information at $contactEmail.';

      throw Exception(msg);
    }
  }

  Future<UserModel> _createNewUserRecord(
    User firebaseUser,
    String email,
    String fullName,
    String phone,
  ) async {
    final deviceInfo = await DeviceHelper.getDeviceInfo();
    final String deviceId = await DeviceHelper.getDeviceId();

    UserModel newUser = UserModel(
      uid: firebaseUser.uid,
      email: email,
      displayName: fullName,
      phone: phone,
      createdAt: DateTime.now(),
      premiumExpiryDate: DateTime(DateTime.now().year, 12, 31, 23, 59, 59),
      deviceId: deviceId,
      deviceInfo: deviceInfo,
    );

    final userData = newUser.toMap();
    userData['lastLogin'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(userData);
    await _cacheUserLocally(newUser);
    return newUser;
  }

  Future<UserModel?> _fetchAndCacheUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        UserModel loggedInUser = UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        // ── Device Binding Verification ──
        final currentDeviceId = await DeviceHelper.getDeviceId();
        if (loggedInUser.deviceId == null || loggedInUser.deviceId!.isEmpty) {
          // If no device registered yet, bind it now!
          await _firestore.collection('users').doc(uid).update({
            'deviceId': currentDeviceId,
          });
          loggedInUser = UserModel(
            uid: loggedInUser.uid,
            email: loggedInUser.email,
            displayName: loggedInUser.displayName,
            phone: loggedInUser.phone,
            createdAt: loggedInUser.createdAt,
            examSelections: loggedInUser.examSelections,
            premiumExpiryDate: loggedInUser.premiumExpiryDate,
            gender: loggedInUser.gender,
            dob: loggedInUser.dob,
            hobbies: loggedInUser.hobbies,
            interests: loggedInUser.interests,
            schoolStatus: loggedInUser.schoolStatus,
            isPremium: loggedInUser.isPremium,
            deviceId: currentDeviceId,
            deviceInfo: loggedInUser.deviceInfo,
            referredBy: loggedInUser.referredBy,
            isActive: loggedInUser.isActive,
          );
        } else if (loggedInUser.deviceId != currentDeviceId) {
          await logout();
          throw Exception(
            'This account is locked to another device. You can only use Pass At Once on your registered device. Please contact support if you need to switch devices.',
          );
        }

        await _cacheUserLocally(loggedInUser);
        return loggedInUser;
      }
    } catch (e, stackTrace) {
      debugPrint('Fetch and Cache User Error: $e\n$stackTrace');
      rethrow;
    }
    return null;
  }

  UserModel? _getUserFromCache() {
    final localUser = Hive.box<LocalUser>(
      HiveSetup.userBoxName,
    ).get('currentUser');
    if (localUser == null) return null;
    return UserModel(
      uid: localUser.uid,
      email: localUser.email,
      displayName: localUser.displayName,
      phone: localUser.phone ?? '--',
      createdAt: localUser.lastUpdated,
      examSelections: localUser.examSelections,
      premiumExpiryDate: localUser.premiumExpiryDate,
      gender: localUser.gender ?? '--',
      dob: localUser.dob ?? '--',
      hobbies: localUser.hobbies ?? '--',
      interests: localUser.interests ?? '--',
      schoolStatus: localUser.schoolStatus ?? '',
      isPremium: localUser.isPremium,
      deviceId: localUser.deviceId,
      deviceInfo: localUser.deviceInfo,
      referredBy: localUser.referredBy,
    );
  }

  Future<void> _cacheUserLocally(UserModel user) async {
    final localUser = LocalUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      examSelections: user.examSelections,
      premiumExpiryDate: user.premiumExpiryDate,
      lastUpdated: DateTime.now(),
      gender: user.gender,
      dob: user.dob,
      hobbies: user.hobbies,
      interests: user.interests,
      schoolStatus: user.schoolStatus,
      phone: user.phone,
      isPremium: user.isPremium,
      deviceId: user.deviceId,
      deviceInfo: user.deviceInfo,
      referredBy: user.referredBy,
    );
    await Hive.box<LocalUser>(
      HiveSetup.userBoxName,
    ).put('currentUser', localUser);
  }

  String _handleAuthError(String errorCode, {bool isGoogle = false}) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Email is not registered. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return isGoogle
            ? 'Google authentication failed. Please try again.'
            : 'Incorrect email or password. Please try again. (If you signed up with Google, please sign in with Google.)';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered using Email and Password. Please login normally.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return isGoogle
            ? 'Google authentication failed. Please try again.'
            : 'Authentication failed. Please try again.';
    }
  }
}
