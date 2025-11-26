import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class CsvLogger {
  Future<File> ensureFile(SharedPreferences prefs) async {
    String? path = prefs.getString('csv_path');
    if (path != null) {
      final f = File(path);
      if (await f.exists()) return f;
    }
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Choose CSV file to save measurements',
        fileName: 'measurements.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        prefs.setString('csv_path', result);
        final file = File(result);
        if (!await file.exists()) await file.create(recursive: true);
        if ((await file.length()) == 0) {
          await file.writeAsString('timestamp,value\n', mode: FileMode.write);
        }
        return file;
      }
    } catch (e) {
      print('File pick failed: $e');
    }
    final dir = await getApplicationDocumentsDirectory();
    final fallback = File('${dir.path}/measurements.csv');
    if (!await fallback.exists()) await fallback.create(recursive: true);
    if ((await fallback.length()) == 0) {
      await fallback.writeAsString('timestamp,value\n', mode: FileMode.write);
    }
    prefs.setString('csv_path', fallback.path);
    return fallback;
  }

  Future<void> append(SharedPreferences prefs, dynamic measurement) async {
    final file = await ensureFile(prefs);
    final timestamp = (measurement.time as DateTime).toIso8601String();
    final value = (measurement.value).toString();
    final csvLine = const ListToCsvConverter().convert([
      [timestamp, value]
    ]);
    await file.writeAsString(csvLine + '\n', mode: FileMode.append);
  }
}
