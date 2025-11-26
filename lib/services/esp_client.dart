import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Callback function types defined for clarity
typedef void ConnectionCallback(bool connected);
typedef void DataCallback(String data);

class EspClient {
  Socket? _socket;
  bool _isConnected = false;

  // --- Callbacks (used by SingleScreenController in main.dart) ---
  ConnectionCallback? onConnectionState;
  DataCallback? onData;

  /// Attempts to establish a TCP connection to the ESP host and port.
  Future<bool> connect(String host, int port) async {
    if (_isConnected) {
      await dispose();
    }

    try {
      debugPrint('Attempting to connect to $host:$port...');
      
      // Attempt to connect with a 5-second timeout
      _socket = await Socket.connect(host, port, timeout: Duration(seconds: 5));
      
      _isConnected = true;
      onConnectionState?.call(true);
      debugPrint('Connected successfully.');

      // Set up listeners for the socket
      _socket!.listen(
        (List<int> data) {
          // Decode the incoming byte data to a string
          final rawData = utf8.decode(data).trim();
          debugPrint('Received raw data: "$rawData"');
          onData?.call(rawData);
        },
        onError: (error) {
          debugPrint('Socket error: $error');
          dispose(); // Automatically disconnect and clean up on error
        },
        onDone: () {
          debugPrint('Socket disconnected (onDone)');
          dispose(); // Automatically disconnect when the remote end closes the connection
        },
        cancelOnError: true,
      );

      return true;
    } catch (e) {
      debugPrint('Connection failed: $e');
      dispose(); // Ensure cleanup if connection fails
      return false;
    }
  }

  /// Sends a string message to the connected ESP device.
  Future<void> send(String message) async {
    if (_socket == null || !_isConnected) {
      debugPrint('Cannot send message: Not connected.');
      return;
    }
    
    try {
      // It's common practice to append a newline (\n) as a message terminator 
      // when communicating with microcontrollers over TCP.
      final dataToSend = utf8.encode('$message\n');
      _socket!.add(dataToSend);
      // Wait for the data to be written to the underlying socket
      await _socket!.flush(); 
      debugPrint('Sent: "$message"');
    } catch (e) {
      debugPrint('Error sending data: $e');
      // If sending fails, assume connection is lost
      dispose();
    }
  }

  /// Closes the connection and resets the connection state.
  Future<void> dispose() async {
    if (_socket != null) {
      debugPrint('Disposing ESP client...');
      // Close the socket gracefully
      await _socket!.close();
      _socket = null;
    }
    if (_isConnected) {
      _isConnected = false;
      onConnectionState?.call(false);
    }
  }

  bool get isConnected => _isConnected;
}
