import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Simple TCP client for talking to an ESP device.
/// This file fixes the StreamTransformer type mismatch: Socket streams
/// produce Uint8List; we explicitly convert Uint8List -> String before
/// using LineSplitter.
class ESPClient {
  Socket? _socket;
  StreamSubscription<String>? _sub;

  final void Function(String line)? onLine;
  final void Function()? onDone;
  final void Function(Object error)? onError;

  ESPClient({this.onLine, this.onDone, this.onError});

  Future<void> connect(String host, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    await close();
    _socket = await Socket.connect(host, port).timeout(timeout);

    // Convert Stream<Uint8List> -> Stream<String> and then split into lines.
    _sub = _socket!
        .transform(StreamTransformer<Uint8List, String>.fromHandlers(
          handleData: (Uint8List data, EventSink<String> sink) {
            // decode chunk and pass on
            try {
              sink.add(utf8.decode(data));
            } catch (e) {
              // If decode fails, attempt fallback
              sink.add(String.fromCharCodes(data));
            }
          },
        ))
        .transform(const LineSplitter())
        .listen((line) {
          if (onLine != null) onLine!(line);
        }, onDone: () {
          if (onDone != null) onDone!();
        }, onError: (e) {
          if (onError != null) onError!(e);
        });
  }

  /// Send a raw string (appends newline if you want).
  void send(String data) {
    if (_socket != null) {
      _socket!.write(data);
    } else {
      throw StateError('Socket not connected');
    }
  }

  /// Close socket and subscription.
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  bool get isConnected => _socket != null;
}
