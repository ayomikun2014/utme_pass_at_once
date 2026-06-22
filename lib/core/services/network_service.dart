import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class NetworkService {
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
    // Initial check
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) async {
    bool online = false;
    
    // connectivity_plus 6.0+ returns a List<ConnectivityResult>
    if (results.contains(ConnectivityResult.none)) {
      online = false;
    } else if (results.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi || 
        result == ConnectivityResult.ethernet || 
        result == ConnectivityResult.vpn)) {
      
      // Even if connectivity says we're on Wifi/Mobile, 
      // we might not have ACTUAL internet access (e.g. captive portal or ISP down)
      online = await _checkActualInternet();
    }

    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
      debugPrint('🌐 Network Status Changed: ${online ? "ONLINE" : "OFFLINE"}');
    }
  }

  /// Pings google.com to verify actual data access
  Future<bool> _checkActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Manual check helper
  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;
    return await _checkActualInternet();
  }

  void dispose() {
    _controller.close();
  }

  // --- FUNNY OFFLINE HELPERS ---

  final List<String> _funnyMessages = [
    "Oops! Your internet is playing hide and seek. 🙈",
    "Whoa! It seems your connection took a coffee break. ☕",
    "No signal! Are we in a tunnel or just really unlucky? 🚇",
    "Internet is down. Time to talk to real people? (Just kidding!) 😅",
    "Your Wi-Fi went for a walk. 🚶‍♂️ It'll be back soon!",
    "Oh no! The internet went on vacation! 🏖️",
    "Lost in the digital wilderness? No signal found! 🌲",
  ];

  /// Show a funny SnackBar when a user clicks a network-required feature while offline
  void showNoInternetHelper(BuildContext context) {
    final message = _funnyMessages[Random().nextInt(_funnyMessages.length)];
    
    CustomToast.show(context, message);
  }

  /// Run an action ONLY if online, otherwise show the funny helper
  void runWithNetwork(BuildContext context, VoidCallback action) {
    if (isOnline) {
      action();
    } else {
      showNoInternetHelper(context);
    }
  }
}
