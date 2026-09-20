import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService with WidgetsBindingObserver {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final Connectivity _connectivity = Connectivity();
  
  // Stream controller to broadcast connectivity status
  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Initialize the network listener
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    // Initial check
    await checkConnectivity();

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App Resumed: Refreshing connectivity status...');
      checkConnectivity();
    }
  }

  /// Actively check and refresh connectivity status
  Future<void> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _updateStatus(results);
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      // Fallback: test actual internet directly if sensor reading fails
      final online = await _checkActualInternet();
      _setOnlineState(online);
    }
  }

  Future<void> _updateStatus(List<ConnectivityResult> results) async {
    bool online = false;
    
    // connectivity_plus 6.0+ returns a List<ConnectivityResult>
    if (results.contains(ConnectivityResult.none)) {
      // Explicitly check actual internet as a fallback
      // (crucial for emulators/devices reporting 'none' incorrectly but having network access)
      online = await _checkActualInternet();
    } else if (results.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi || 
        result == ConnectivityResult.ethernet || 
        result == ConnectivityResult.vpn)) {
      
      // If we have an active network interface, we assume we are online.
      // We perform a fast socket lookup in the background to confirm route access.
      online = await _checkActualInternet();
    }

    _setOnlineState(online);
  }

  void _setOnlineState(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
      debugPrint('🌐 Network Status Changed: ${online ? "ONLINE" : "OFFLINE"}');
    }
  }

  /// Pings public DNS servers via socket or falls back to DNS lookup
  Future<bool> _checkActualInternet() async {
    final List<String> ips = ['8.8.8.8', '1.1.1.1', '208.67.222.222'];
    
    try {
      // 1. Try socket connections to port 53 (DNS port) first - fast, bypasses DNS overhead/weaknesses
      final socketResults = await Future.wait(
        ips.map((ip) => _testSocketConnection(ip)),
      );
      if (socketResults.any((success) => success)) return true;
    } catch (_) {}

    // 2. Fallback: If port 53 is blocked or fails, try standard DNS lookup for google.com
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {}

    return false;
  }

  Future<bool> _testSocketConnection(String ip) async {
    try {
      final socket = await Socket.connect(ip, 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Manual check helper that also updates the internal state
  Future<bool> hasInternet() async {
    final online = await _checkActualInternet();
    _setOnlineState(online);
    return online;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }

  /// Show a professional SnackBar when a user clicks a network-required feature while offline
  void showNoInternetHelper(BuildContext context) {
    CustomToast.show(
      context,
      "Connection failed. Please check your internet or connect to the internet.",
      isError: true,
    );
  }

  /// Run an action ONLY if online, otherwise show the no internet helper.
  /// If we currently think we are offline, perform a fast background lookup to ensure the state isn't stale.
  Future<void> runWithNetwork(BuildContext context, VoidCallback action) async {
    bool activeOnline = _isOnline;
    if (!activeOnline) {
      activeOnline = await _checkActualInternet().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => false,
      );
      if (activeOnline) {
        _setOnlineState(true);
      }
    }

    if (activeOnline) {
      action();
    } else {
      if (!context.mounted) return;
      showNoInternetHelper(context);
    }
  }
}
