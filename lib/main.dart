import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'services/wifi_service.dart';
// Note: This relies on the updated EspClient class definition
import 'services/esp_client.dart'; 
import 'services/csv_logger.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SwitchyApp());
}

class SwitchyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Switchy',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SingleScreenController(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SingleScreenController extends StatefulWidget {
  @override
  _SingleScreenControllerState createState() => _SingleScreenControllerState();
}

class _SingleScreenControllerState extends State<SingleScreenController> {
  // Uses EspClient (assuming it was renamed in services/esp_client.dart as well)
  final EspClient _esp = EspClient(); 
  final WifiService _wifi = WifiService();
  final CsvLogger _csv = CsvLogger();

  bool _connectedToWifi = false;
  bool _espConnected = false;
  bool _switchOn = false;

  List<Measurement> _data = [];

  late SharedPreferences _prefs;

  // settings
  String _espSsid = 'ESP-AP';
  String _espPassword = '';
  String _espHost = '192.168.4.1';
  int _espPort = 80;
  String _msgOn = 'ON';
  String _msgOff = 'OFF';

  @override
  void initState() {
    super.initState();
    _loadSettings().then((_) => _start());
    // These callbacks match the updated EspClient interface
    _esp.onData = _onEspData;
    _esp.onConnectionState = (connected) {
      setState(() => _espConnected = connected);
    };
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _espSsid = _prefs.getString('esp_ssid') ?? _espSsid;
      _espPassword = _prefs.getString('esp_pwd') ?? _espPassword;
      _espHost = _prefs.getString('esp_host') ?? _espHost;
      _espPort = _prefs.getInt('esp_port') ?? _espPort;
      _msgOn = _prefs.getString('msg_on') ?? _msgOn;
      _msgOff = _prefs.getString('msg_off') ?? _msgOff;
    });
  }

  Future<void> _start() async {
    // FIX: Changed _wifi.connectToNetwork to _wifi.connect
    final result = await _wifi.connect(_espSsid, password: _espPassword);
    _connectedToWifi = result ?? false; // Handle potential null result from plugin
    setState(() {});
    
    // If Wi-Fi is connected, attempt to connect to the ESP client
    if (_connectedToWifi) {
      await _esp.connect(_espHost, _espPort);
    }
  }

  Future<void> _onEspData(String raw) async {
    double? value;
    raw = raw.trim();
    try {
      // Direct parse
      value = double.parse(raw);
    } catch (_) {
      // Fallback: Check if data is wrapped (e.g., {"value": 12.3})
      if (raw.contains('value')) {
        final match = RegExp(r'(-?\d+(\.\d+)?)').firstMatch(raw);
        if (match != null) value = double.tryParse(match.group(0)!);
      }
    }
    
    if (value != null) {
      final m = Measurement(DateTime.now(), value);
      setState(() {
        _data.add(m);
        // Keep the data list size manageable
        if (_data.length > 200) _data.removeAt(0);
      });
      // Log measurement to CSV
      await _csv.append(_prefs, m);
    }
  }

  Future<void> _toggleSwitch(bool newValue) async {
    setState(() => _switchOn = newValue);
    final msg = newValue ? _msgOn : _msgOff;
    
    if (_espConnected) {
      await _esp.send(msg);
    } else {
      // If not connected, try to reconnect to the ESP
      if (_connectedToWifi) await _esp.connect(_espHost, _espPort);
      // If reconnection succeeds, send the message
      if (_espConnected) await _esp.send(msg);
    }
  }

  void _openSettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => SettingsDialog(
        ssid: _espSsid,
        password: _espPassword,
        host: _espHost,
        port: _espPort,
        msgOn: _msgOn,
        msgOff: _msgOff,
      ),
    );
    // Reload settings and restart connection if settings were saved (result is true)
    if (result == true) {
      await _loadSettings();
      await _start();
    }
  }

  Widget _buildStatusIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // FIX: Replaced deprecated Icon.tooltip with Tooltip widget
        Tooltip(
          message: _connectedToWifi ? 'Connected to ESP Wi-Fi' : 'Not connected to ESP Wi-Fi',
          child: Icon(_connectedToWifi ? Icons.wifi : Icons.wifi_off,
              color: _connectedToWifi ? Colors.green : Colors.red),
        ),
        SizedBox(width: 8),
        // FIX: Replaced deprecated Icon.tooltip with Tooltip widget
        Tooltip(
          message: _espConnected ? 'ESP Client Connected' : 'ESP Client Disconnected',
          child: Icon(_espConnected ? Icons.usb : Icons.usb_off,
              color: _espConnected ? Colors.green : Colors.red),
        ),
      ],
    );
  }

  Widget _buildGraph() {
    if (_data.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Text('No data yet'),
      );
    }

    final minTime = _data.first.time.millisecondsSinceEpoch.toDouble();
    final spots = _data.map((m) {
      // X-axis is time difference in seconds from the first measurement
      final x = (m.time.millisecondsSinceEpoch.toDouble() - minTime) / 1000.0;
      return FlSpot(x, m.value.toDouble());
    }).toList();

    final maxX = spots.last.x;
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: minY - 1, // Add buffer for better visualization
            maxY: maxY + 1, // Add buffer for better visualization
            lineBarsData: [
              LineChartBarData(
                spots: spots, 
                isCurved: true, 
                color: Colors.blue, // Curve color
                barWidth: 3,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, 
                  reservedSize: 28, 
                  interval: (maxX / 5).clamp(10, 60).toDouble(), // dynamic interval
                  getTitlesWidget: (v, meta) {
                    final seconds = v.toInt();
                    // Convert seconds back to DateTime for formatted display
                    final display = DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch((minTime + seconds * 1000).toInt()));
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(display, style: TextStyle(fontSize: 10)));
                  }
                )
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _esp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Switchy'),
        actions: [
          _buildStatusIcons(),
          IconButton(icon: Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _data.clear(); // Clear data on manual refresh for a fresh start/test
          await _start();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: 24),
              // --- Power Switch Card ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Power', style: TextStyle(fontSize: 24)),
                        Switch(
                          value: _switchOn,
                          onChanged: _espConnected ? (v) => _toggleSwitch(v) : null, // Disable switch if ESP not connected
                          activeColor: Colors.green,
                          activeTrackColor: Colors.greenAccent,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // --- Graph ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text('Live Data Stream (Last 200 Points)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildGraph(),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // --- Recent Data List ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Measurements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._data.reversed.take(10).map((m) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.timeline, color: Colors.blueAccent),
                        title: Text('${m.value.toStringAsFixed(2)}'),
                        subtitle: Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(m.time)),
                      );
                    }).toList(),
                  ],
                ),
              ),
              SizedBox(height: 48),
            ],
          ),
        ),
      ),
      // --- Floating Action Button for CSV Export ---
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.file_download),
        tooltip: 'Export CSV now',
        onPressed: () async {
          final file = await _csv.ensureFile(_prefs);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logging to ${file.path}')));
          }
        },
      ),
    );
  }
}

// --- Data Model Class ---
class Measurement {
  final DateTime time;
  final double value;
  Measurement(this.time, this.value);
}

// --- Settings Dialog Widget ---
class SettingsDialog extends StatefulWidget {
  final String ssid;
  final String password;
  final String host;
  final int port;
  final String msgOn;
  final String msgOff;

  SettingsDialog({required this.ssid, required this.password, required this.host, required this.port, required this.msgOn, required this.msgOff});

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _ssid;
  late TextEditingController _pwd;
  late TextEditingController _host;
  late TextEditingController _port;
  late TextEditingController _msgOn;
  late TextEditingController _msgOff;

  @override
  void initState() {
    super.initState();
    _ssid = TextEditingController(text: widget.ssid);
    _pwd = TextEditingController(text: widget.password);
    _host = TextEditingController(text: widget.host);
    _port = TextEditingController(text: widget.port.toString());
    _msgOn = TextEditingController(text: widget.msgOn);
    _msgOff = TextEditingController(text: widget.msgOff);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _ssid, decoration: InputDecoration(labelText: 'ESP SSID')),
            TextField(controller: _pwd, decoration: InputDecoration(labelText: 'ESP Password (if any)')),
            TextField(controller: _host, decoration: InputDecoration(labelText: 'ESP Host (IP)'), keyboardType: TextInputType.url),
            TextField(controller: _port, decoration: InputDecoration(labelText: 'ESP Port'), keyboardType: TextInputType.number),
            TextField(controller: _msgOn, decoration: InputDecoration(labelText: 'Message for ON')),
            TextField(controller: _msgOff, decoration: InputDecoration(labelText: 'Message for OFF')),
            SizedBox(height: 8),
            Text('CSV file location can be chosen from app UI (floating button)'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')),
        TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              // Save settings
              await prefs.setString('esp_ssid', _ssid.text.trim());
              await prefs.setString('esp_pwd', _pwd.text);
              await prefs.setString('esp_host', _host.text.trim());
              await prefs.setInt('esp_port', int.tryParse(_port.text) ?? 80);
              await prefs.setString('msg_on', _msgOn.text);
              await prefs.setString('msg_off', _msgOff.text);
              Navigator.of(context).pop(true);
            },
            child: Text('Save')),
      ],
    );
  }
}
