import 'dart:async';
import 'package:wifi_iot/wifi_iot.dart';

class WifiService {
  /// Returns true if WiFi is enabled on the device.
  Future<bool?> isEnabled() {
    return WiFiForIoTPlugin.isEnabled();
  }

  /// Return a list of available networks (platform dependent).
  Future<List<dynamic>?> loadWifiList() {
    return WiFiForIoTPlugin.loadWifiList();
  }

  /// Connect to an access point. Adjust options (security) as needed.
  /// Example:
  ///   await connect('my-ssid', password: 'mypassword');
  Future<bool?> connect(String ssid, {String? password, NetworkSecurity? security}) {
    return WiFiForIoTPlugin.connect(
      ssid,
      password: password ?? '',
      security: security ?? NetworkSecurity.WPA,
    );
  }

  /// Disconnect from current WiFi.
  Future<bool?> disconnect() {
    return WiFiForIoTPlugin.disconnect();
  }
}
