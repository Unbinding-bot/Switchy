import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// Note: In a real project, you would import 'package:path_provider/path_provider.dart'

/// Helper class to manage data logging to a local CSV file.
class CsvLogger {
  static const String _csvFilePathKey = 'csvFilePath';
  static const String _defaultFileName = 'switchy_data.csv';

  /// Ensures the CSV file exists and returns the File object.
  /// If no path is saved in SharedPreferences, it defaults to a path.
  Future<File> ensureFile(SharedPreferences prefs) async {
    // --- REAL WORLD IMPLEMENTATION using path_provider ---
    // final directory = await getApplicationDocumentsDirectory();
    // final defaultPath = '${directory.path}/$_defaultFileName';
    // String filePath = prefs.getString(_csvFilePathKey) ?? defaultPath;
    // ---------------------------------------------------

    // --- SIMULATION (for running in this environment) ---
    // In this environment, we simulate a file path.
    String filePath = prefs.getString(_csvFilePathKey) ?? _defaultFileName;
    // ----------------------------------------------------

    final file = File(filePath);

    // If the file does not exist, create it and write the header.
    if (!await file.exists()) {
      await file.writeAsString('Timestamp,Value\n', mode: FileMode.write);
      debugPrint('Created new CSV file with header at: $filePath');
    }

    // Save the potentially new default path back to preferences
    await prefs.setString(_csvFilePathKey, filePath);
    return file;
  }

  /// Appends a new measurement entry to the CSV file.
  Future<void> append(SharedPreferences prefs, dynamic measurement) async {
    try {
      final file = await ensureFile(prefs);
      
      // Determine the data to log. Assuming 'measurement' is the Measurement 
      // class (or a similar object) from main.dart.
      // We safely handle dynamic typing and ensure proper formatting.
      String logLine = '';

      if (measurement is Map<String, dynamic>) {
        // If passed a map (flexible logging)
        final timestamp = measurement['time'] is DateTime 
            ? DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(measurement['time'] as DateTime)
            : measurement['time'].toString();
        final value = measurement['value'].toString();
        logLine = '$timestamp,$value\n';
      } else if (measurement.runtimeType.toString() == 'Measurement') {
        // Use reflection-like check for the specific data model from main.dart
        // Requires dynamic access to 'time' and 'value' properties
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(measurement.time as DateTime);
        final value = measurement.value.toString();
        logLine = '$timestamp,$value\n';
      } else {
        debugPrint('CSVLogger: Unhandled measurement type for logging.');
        return;
      }

      // Append the new line to the file. FileMode.append creates the file if it doesn't exist, 
      // but we use ensureFile() first to guarantee the header is written.
      await file.writeAsString(logLine, mode: FileMode.append);
      // debugPrint('Logged: $logLine'); // Too noisy for every point
    } catch (e) {
      debugPrint('CSVLogger: Failed to append data to CSV: $e');
    }
  }
  
  /// Placeholder for allowing the user to set a custom file path.
  /// In a real app, this would use file picker plugins.
  Future<void> setCustomFilePath(SharedPreferences prefs, String newPath) async {
    if (newPath.isNotEmpty) {
      await prefs.setString(_csvFilePathKey, newPath);
      debugPrint('CSV file path updated to: $newPath');
    }
  }
}
