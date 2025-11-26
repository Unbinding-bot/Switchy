import 'dart:async';

import 'package:wifi_iot/wifi_iot.dart';

/// Small wrapper around the wifi_iot plugin to give the app a stable API.
/// Adjust methods to your app's needs.
class WifiService {
  /// Returns true if WiFi is enabled on the device (may be null on some platforms).
  Future<bool?> isEnabled() {
    return WiFiForIoTPlugin.isEnabled();
  }

  /// Load a list of available networks. Platform dependent; returns List<dynamic>.
  Future<List<dynamic>?> loadWifiList() {
    return WiFiForIoTPlugin.loadWifiList();
  }

  /// Connect to an access point. Provide password if needed.
  /// Returns true/false or null depending on platform implementation.
  Future<bool?> connect(String ssid, {String password = '', NetworkSecurity? security, bool joinOnce = false}) {
    return WiFiForIoTPlugin.connect(
      ssid,
      password: password,
      joinOnce: joinOnce,
      security: security ?? NetworkSecurity.WPA,
    );
  }

  /// Disconnect from current WiFi network.
  Future<bool?> disconnect() {
    return WiFiForIoTPlugin.disconnect();
  }
}
