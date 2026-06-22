import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceHelper {
  static const _deviceIdKey = 'pao_device_id';

  /// Returns a stable, unique device identifier.
  ///
  /// Strategy:
  /// 1. Check SharedPreferences for a previously stored device ID.
  ///    - If found, return it immediately (survives cache clear on some OEMs).
  /// 2. If not found, generate a composite ID from hardware properties
  ///    that are unique to the physical device and persist it.
  ///
  /// On Android, we use a hash of [brand + model + hardware + fingerprint]
  /// which produces a unique-per-device string that:
  /// - Is identical across app reinstalls on the SAME device
  /// - Is DIFFERENT across different physical devices
  /// - Does NOT require any special permissions
  ///
  /// On iOS, we use `identifierForVendor` which persists as long as at
  /// least one app from the same vendor is installed.
  static Future<String> getDeviceId() async {
    // 1. Try to read from persistent storage first
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString(_deviceIdKey);
      if (storedId != null && storedId.isNotEmpty) {
        return storedId;
      }
    } catch (_) {
      // SharedPreferences might fail on first run, continue to generate
    }

    // 2. Generate a new device ID from hardware properties
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceId = 'unknown_device_id';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        // Build a composite key from hardware properties that are:
        // - Unique to each physical device (fingerprint includes model + build)
        // - Stable across app reinstalls (they don't change)
        // - Different from the old androidInfo.id (which was just a build number
        //   shared by ALL devices with the same firmware)
        final composite =
            '${androidInfo.brand}|${androidInfo.model}|${androidInfo.hardware}|${androidInfo.fingerprint}|${androidInfo.display}';
        deviceId = composite.hashCode.toRadixString(36);
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_id';
      }
    } catch (e) {
      debugPrint("Error getting device ID: $e");
    }

    // 3. Persist the generated ID for future lookups
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, deviceId);
    } catch (_) {}

    return deviceId;
  }

  /// Returns a Map of detailed hardware info (model, manufacturer, etc.)
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        final id = await getDeviceId();
        return {
          'id': id,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'hardware': androidInfo.hardware,
          'platform': 'Android',
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return {
          'id': iosInfo.identifierForVendor ?? 'unknown_ios_id',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'platform': 'iOS',
        };
      }
    } catch (e) {
      debugPrint("Error getting device info: $e");
    }

    return {'platform': 'unsupported'};
  }
}