import 'dart:io';
import 'dart:convert';

typedef OnData = void Function(String raw);
typedef OnConnection = void Function(bool connected);

class EspClient {
  Socket? _socket;
  OnData? onData;
  OnConnection? onConnectionState;

  Future<void> connect(String host, int port) async {
    try {
      _socket?.destroy();
      _socket = await Socket.connect(host, port, timeout: Duration(seconds: 5));
      onConnectionState?.call(true);
      _socket!.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (onData != null) onData!(line);
      }, onDone: () {
        onConnectionState?.call(false);
      }, onError: (e) {
        onConnectionState?.call(false);
      });
    } catch (e) {
      onConnectionState?.call(false);
      print('ESP connect error: $e');
    }
  }

  Future<void> send(String message) async {
    try {
      if (_socket == null) throw Exception('Not connected');
      _socket!.write(message + '\n');
      await _socket!.flush();
    } catch (e) {
      print('Send failed: $e');
    }
  }

  void dispose() {
    _socket?.destroy();
    _socket = null;
  }
}
