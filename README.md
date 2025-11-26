# Switchy

This branch implements a single-screen app that connects to an ESP32/ESP8266 running as a Wi-Fi AP. Features:

- Single screen UI: big switch, status icons, scrollable usage graph, recent list
- Auto-join ESP Wi-Fi (Android supported; iOS limited)
- TCP client to send configured ON/OFF messages and receive usage values
- CSV logging with file picker and fallback to app documents directory

Notes:
- Android permissions for Wi-Fi scanning/joining and file access may be required. Add runtime permission handling to your app if needed.
- iOS may require entitlements and user interaction to join Wi-Fi networks.

How to test:
1. Set your ESP's SSID in Settings and, if needed, password. Also set the ESP host (usually 192.168.4.1) and port.
2. Run the app on device. It will attempt to join the ESP AP and open a TCP socket.
3. Toggle the big switch to send the configured ON/OFF messages. The app expects numeric usage lines or JSON lines containing a numeric field named "value".

If you need the app to use HTTP, UDP, or MQTT instead of plain TCP lines, tell me and I will adjust the client.
