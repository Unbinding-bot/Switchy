import 'package:wifi_iot/wifi_iot.dart';

class WifiService {
  Future<bool> connectToNetwork(String ssid, String password) async {
    try {
      bool connected = false;
      if (password.isEmpty) {
        connected = await WiFiForIoTPlugin.connect(ssid, joinOnce: true, withInternet: false);
      } else {
        connected = await WiFiForIoTPlugin.connect(ssid, password: password, joinOnce: true, withInternet: false);
      }
      return connected;
    } catch (e) {
      print('Wifi connect failed: $e');
      return false;
    }
  }
}
