import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkHelper {
  /// Checks if the device has an active internet connection.
  static Future<bool> hasInternet() async {
    try {
      // 1. First, quickly check connectivity_plus network interfaces
      await (Connectivity().checkConnectivity());

      // 2. Perform a real domain lookup to ensure actual internet route is available
      // This is crucial for emulators that might report no interface or 'none' but still have internet.
      return await _checkRealInternet();
    } catch (e) {
      // In case of an error accessing device sensors, fallback to real internet check
      return await _checkRealInternet();
    }
  }

  static Future<bool> _checkRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}
