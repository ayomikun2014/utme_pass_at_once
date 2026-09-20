import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_lock_exception.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// An admin's account belongs to the admin panel.
  ///
  /// The panel turns away anyone who is not an admin; this is the same door on
  /// this side. Without it an admin's email signs in here as well and picks up
  /// a student profile, which muddles the two.
  Future<void> _refuseAdminAccount(User firebaseUser) async {
    bool isAdmin = false;
    try {
      final adminDoc =
          await _firestore.collection('admins').doc(firebaseUser.uid).get();
      isAdmin = adminDoc.exists;
    } catch (e) {
      // Cannot tell right now (no connection, say). Let the sign-in through
      // rather than locking a student out over a failed lookup.
      debugPrint('Admin check skipped: $e');
      return;
    }
    if (!isAdmin) return;

    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    throw Exception(
      'This email is registered for the admin panel. Sign in to the admin '
      'panel with it, or use a different email for the student app.',
    );
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
        await _refuseAdminAccount(cred.user!);

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
      // A device lock is passed on by type: its wording changes with how
      // many self-service moves are left, so matching the text missed it.
      if (e is DeviceLockException ||
          e.toString().contains('suspended by the admin')) {
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
        firebaseUser = await _signInWithGoogleMobileWithRetry();
        if (firebaseUser == null) return null;
        defaultEmail = firebaseUser.email;
        defaultName = firebaseUser.displayName;
      }

      if (firebaseUser == null) {
        throw Exception('Authentication failed securely.');
      }

      await _refuseAdminAccount(firebaseUser);

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
      final isStale =
          e.code == 'invalid-credential' ||
          (e.message != null && e.message!.contains('stale'));
      if (isStale) {
        throw Exception(
          "Your phone's date and time are incorrect. Please go to your settings and correct your date and time to continue.",
        );
      }
      throw Exception(_handleAuthError(e.code, isGoogle: true));
    } on GoogleSignInUnavailable {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In General Exception: $e\n$stackTrace');
      // A device lock is passed on by type: its wording changes with how
      // many self-service moves are left, so matching the text missed it.
      if (e is DeviceLockException ||
          e.toString().contains('suspended by the admin')) {
        rethrow;
      }
      throw Exception('Google Sign-In Error: $e');
    }
  }

  Future<User?> _signInWithGoogleMobileWithRetry({bool isRetry = false}) async {
    try {
      await GoogleSignIn.instance.signOut();

      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        // Only a real cancel is silent. Anything else -- most often an app
        // signing key that Firebase does not know -- used to be swallowed
        // here and surface as "User profile data is missing".
        if (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted) {
          debugPrint('Google Sign-In was cancelled by the user: $e');
          return null;
        }
        debugPrint('Google Sign-In failed [${e.code}]: ${e.description}');
        throw GoogleSignInUnavailable(e.code, e.description);
      }

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google Sign-In failed securely: No ID Token generated.',
        );
      }

      final authClient = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);
      final accessToken = authClient.accessToken;

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Google Mobile Sign-In FirebaseAuthException [${e.code}]: ${e.message}',
      );
      final isStale =
          e.code == 'invalid-credential' ||
          (e.message != null && e.message!.contains('stale'));
      if (isStale && !isRetry) {
        debugPrint(
          '⚠️ Stale Google ID token detected. Disconnecting and retrying...',
        );
        try {
          await GoogleSignIn.instance.disconnect();
        } catch (discErr) {
          debugPrint('Error during Google disconnect: $discErr');
        }
        return await _signInWithGoogleMobileWithRetry(isRetry: true);
      }
      rethrow;
    } on GoogleSignInUnavailable {
      rethrow;
    } catch (e) {
      debugPrint('Google Mobile Sign-In Exception: $e');
      final isStale =
          e.toString().contains('invalid-credential') ||
          e.toString().contains('stale');
      if (isStale && !isRetry) {
        debugPrint(
          '⚠️ Stale Google ID token detected (general catch). Disconnecting and retrying...',
        );
        try {
          await GoogleSignIn.instance.disconnect();
        } catch (discErr) {
          debugPrint('Error during Google disconnect: $discErr');
        }
        return await _signInWithGoogleMobileWithRetry(isRetry: true);
      }
      rethrow;
    }
  }

  Future<void> _reauthenticateGoogleMobileWithRetry(
    User user, {
    bool isRetry = false,
  }) async {
    try {
      await GoogleSignIn.instance.signOut();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } catch (e) {
        debugPrint('Google Re-auth was cancelled by the user: $e');
        throw Exception('Google re-authentication was cancelled.');
      }

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google Re-auth failed securely: No ID Token generated.',
        );
      }

      final authClient = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);
      final accessToken = authClient.accessToken;

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Google Re-auth FirebaseAuthException [${e.code}]: ${e.message}',
      );
      final isStale =
          e.code == 'invalid-credential' ||
          (e.message != null && e.message!.contains('stale'));
      if (isStale && !isRetry) {
        debugPrint(
          '⚠️ Stale Google ID token detected during re-auth. Disconnecting and retrying...',
        );
        try {
          await GoogleSignIn.instance.disconnect();
        } catch (discErr) {
          debugPrint('Error during Google disconnect: $discErr');
        }
        await _reauthenticateGoogleMobileWithRetry(user, isRetry: true);
        return;
      }
      rethrow;
    } catch (e) {
      debugPrint('Google Re-auth Exception: $e');
      final isStale =
          e.toString().contains('invalid-credential') ||
          e.toString().contains('stale');
      if (isStale && !isRetry) {
        debugPrint(
          '⚠️ Stale Google ID token detected during re-auth (general catch). Disconnecting and retrying...',
        );
        try {
          await GoogleSignIn.instance.disconnect();
        } catch (discErr) {
          debugPrint('Error during Google disconnect: $discErr');
        }
        await _reauthenticateGoogleMobileWithRetry(user, isRetry: true);
        return;
      }
      rethrow;
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
        // Reauthenticate with Google (using retry helper to handle stale credentials)
        await _reauthenticateGoogleMobileWithRetry(user);
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
            debugPrint(
              "Failed to delete subcollection $subName during self-delete: $e",
            );
          }
        }());
      }

      // Wait for all subcollection cleanups to complete
      await Future.wait(deleteFutures);

      // Finally, delete the top-level user document
      await userRef.delete();

      // Clear all local database/caches/preferences associated with the user
      await _clearAllLocalUserData(user.uid);

      // Delete Firebase Auth user
      await user.delete();
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('Delete Account Error [${e.code}]: ${e.message}\n$stackTrace');
      final isStale =
          e.code == 'invalid-credential' ||
          (e.message != null && e.message!.contains('stale'));
      if (isStale) {
        throw Exception(
          "Your phone's date and time are incorrect. Please go to your settings and correct your date and time to continue.",
        );
      }
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password.');
      }
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<void> _clearAllLocalUserData(String uid) async {
    try {
      debugPrint('🧹 Starting complete local user data cleanup for UID: $uid');

      // 1. Clear local Hive user box
      await Hive.box<LocalUser>(HiveSetup.userBoxName).clear();

      // 2. Clear user-specific SharedPreferences caches
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('notes_') ||
            key.startsWith('cached_purchases_') ||
            key.startsWith('cached_classroom_') ||
            key.startsWith('classroom_practice_') ||
            key.startsWith('tutorial_completed_') ||
            key == 'cached_ai_messages' ||
            key == 'favorite_video_ids' ||
            key == 'read_notice_ids') {
          await prefs.remove(key);
          debugPrint('🧹 Cleaned local SharedPreferences key: $key');
        }
      }
    } catch (e) {
      debugPrint('Error clearing SharedPreferences local data: $e');
    }

    try {
      // 3. Clear user-specific/local Hive boxes
      // Local Exam History Box
      final examHistoryBox = await Hive.openBox<String>('exam_history_local');
      await examHistoryBox.clear();
      await examHistoryBox.close();
      debugPrint('🧹 Cleaned exam_history_local Hive box.');

      // Bookmarked Questions Box
      final bookmarkBox = await Hive.openBox<String>('bookmarked_questions');
      await bookmarkBox.clear();
      await bookmarkBox.close();
      debugPrint('🧹 Cleaned bookmarked_questions Hive box.');
    } catch (e) {
      debugPrint('Error clearing Hive local data boxes: $e');
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
    final signedIn = _auth.currentUser;
    if (signedIn != null) {
      // An admin who was already signed in here before the two were separated.
      await _refuseAdminAccount(signedIn);
    }
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
      // A device lock is passed on by type: its wording changes with how
      // many self-service moves are left, so matching the text missed it.
      if (e is DeviceLockException ||
          e.toString().contains('suspended by the admin')) {
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
      // A device lock is passed on by type: its wording changes with how
      // many self-service moves are left, so matching the text missed it.
      if (e is DeviceLockException ||
          e.toString().contains('suspended by the admin')) {
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

    await _firestore.collection('users').doc(firebaseUser.uid).set(userData);
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
          // Signed in on a phone this account is not bound to. The session is
          // deliberately left open: moving the binding is a write to the
          // reader's own document, so they must still be authenticated for it.
          // The sign-in screen either moves them or signs them out.
          final data = doc.data() as Map<String, dynamic>;
          final used = (data['deviceChangeCount'] as num?)?.toInt() ?? 0;
          final limit =
              (data['deviceChangeLimit'] as num?)?.toInt() ?? selfServiceMoves;
          throw DeviceLockException(
            uid: uid,
            movesLeft: (limit - used).clamp(0, limit),
            boundDeviceName: _describeDevice(loggedInUser.deviceInfo),
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

  /// How many times a reader may move their account to a new phone on their
  /// own before an admin has to step in. Kept small on purpose: it covers a
  /// lost or replaced phone without letting one activation be passed around.
  static const int selfServiceMoves = 2;

  static String? _describeDevice(Map<String, dynamic>? info) {
    if (info == null) return null;
    final name = (info['model'] ?? info['name'] ?? info['device'])?.toString();
    final brand = (info['brand'] ?? info['manufacturer'])?.toString();
    if (name == null || name.trim().isEmpty) return null;
    return (brand == null || brand.trim().isEmpty || name.startsWith(brand))
        ? name
        : '$brand $name';
  }

  /// Move the account -- and everything it has bought -- onto this phone.
  ///
  /// The activation lives on the top level `deviceId` and again inside every
  /// entry of `examSelections`, so all of them move together; leaving any
  /// behind would sign the reader in but keep their exams locked. The old
  /// phone is signed out the next time it checks, because its id no longer
  /// matches.
  Future<UserModel?> moveAccountToThisDevice(String uid) async {
    final newDeviceId = await DeviceHelper.getDeviceId();
    final newDeviceInfo = await DeviceHelper.getDeviceInfo();
    final ref = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Account not found.');
      }
      final data = snap.data() as Map<String, dynamic>;
      final used = (data['deviceChangeCount'] as num?)?.toInt() ?? 0;
      final limit =
          (data['deviceChangeLimit'] as num?)?.toInt() ?? selfServiceMoves;
      if (used >= limit) {
        throw DeviceLockException(uid: uid, movesLeft: 0);
      }

      final previous = data['deviceId'];
      final updates = <String, dynamic>{
        'deviceId': newDeviceId,
        'deviceInfo': newDeviceInfo,
        'deviceChangeCount': used + 1,
        'deviceHistory': FieldValue.arrayUnion([
          {
            'from': previous,
            'to': newDeviceId,
            'at': DateTime.now().toIso8601String(),
            'by': 'user',
            'device': _describeDevice(newDeviceInfo),
          },
        ]),
      };

      // every purchase carries its own copy of the binding
      final selections = data['examSelections'];
      if (selections is Map) {
        for (final examType in selections.keys) {
          final selection = selections[examType];
          if (selection is Map && selection.containsKey('deviceId')) {
            updates['examSelections.$examType.deviceId'] = newDeviceId;
          }
        }
      }

      tx.update(ref, updates);
    });

    return _fetchAndCacheUser(uid);
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
      isPremium: user.isPremiumGlobal,
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

/// Google sign-in could not run at all (as opposed to the user backing out).
class GoogleSignInUnavailable implements Exception {
  GoogleSignInUnavailable(this.code, this.description);

  final GoogleSignInExceptionCode code;
  final String? description;

  @override
  String toString() => switch (code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google Sign-In is not available on this version of the app yet. '
              'Please sign in with your email and password, or try again later.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google Sign-In could not open on this device. Please make sure a '
              'Google account is added in your phone settings.',
        _ => 'Google Sign-In failed. Please try again.',
      };
}
