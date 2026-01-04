import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/namkeen_theme.dart';
import '../../services/printing_service.dart';

class PrinterScanScreen extends StatefulWidget {
  const PrinterScanScreen({super.key});

  @override
  State<PrinterScanScreen> createState() => _PrinterScanScreenState();
}

class _PrinterScanScreenState extends State<PrinterScanScreen> {
  final PrintingService _service = PrintingService();
  List<BluetoothInfo> _devices = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    // Get Paired Devices (Fastest)
    final bonded = await _service.getBondedDevices();
    setState(() {
      _devices = bonded;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Printer'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_scanning) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scan)
        ],
      ),
      body: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return ListTile(
            leading: const Icon(Icons.print, color: Colors.blueGrey),
            title: Text(device.name),
            subtitle: Text(device.macAdress),
            onTap: () async {
              // Try connecting
              final success = await _service.connect(device.macAdress);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${device.name}')));
                  Navigator.pop(context, device);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Failed')));
                }
              }
            },
          );
        },
      ),
    );
  }
}
