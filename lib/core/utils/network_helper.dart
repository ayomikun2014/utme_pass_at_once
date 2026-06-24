import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkHelper {
  /// Checks if the device has an active internet connection.
  static Future<bool> hasInternet() async {
    try {
      // 1. First, quickly check connectivity_plus network interfaces
      await Connectivity().checkConnectivity();
      
      // 2. Test actual internet route access
      return await _checkRealInternet();
    } catch (e) {
      // In case of an error accessing device sensors, fallback to real internet check
      return await _checkRealInternet();
    }
  }

  static Future<bool> _checkRealInternet() async {
    final List<String> ips = ['8.8.8.8', '1.1.1.1', '208.67.222.222'];
    
    try {
      // Try socket connections first - fast, no DNS overhead
      final socketResults = await Future.wait(
        ips.map((ip) => _testSocketConnection(ip)),
      );
      if (socketResults.any((success) => success)) return true;
    } catch (_) {}

    // Fallback: standard DNS lookup for google.com
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _testSocketConnection(String ip) async {
    try {
      final socket = await Socket.connect(ip, 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
