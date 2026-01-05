import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import '../../core/namkeen_theme.dart';
import '../../services/printing_service.dart';

class PrinterScanScreen extends StatefulWidget {
  const PrinterScanScreen({super.key});

  @override
  State<PrinterScanScreen> createState() => _PrinterScanScreenState();
}

class _PrinterScanScreenState extends State<PrinterScanScreen> with SingleTickerProviderStateMixin {
  final PrintingService _service = PrintingService();
  late TabController _tabController;
  PrinterType _selectedType = PrinterType.bluetooth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedType = _tabController.index == 0 ? PrinterType.bluetooth : PrinterType.usb;
        });
        _service.startScan(_selectedType);
      }
    });

    // Initial Scan
    // Slight delay to ensure build? Not strictly needed usually.
    _service.startScan(_selectedType);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _service.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Printer'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.usb), text: 'USB'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () => _service.startScan(_selectedType)
          )
        ],
      ),
      body: StreamBuilder<List<PrinterDevice>>(
        stream: _service.scanResults,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final devices = snapshot.data ?? [];
          if (devices.isEmpty) {
             return Center(child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.search_off, size: 48, color: Colors.grey),
                 const SizedBox(height: 16),
                 Text('No ${_selectedType.name} printers found', style: const TextStyle(color: Colors.grey)),
                 if (_selectedType == PrinterType.usb)
                   const Padding(
                     padding: EdgeInsets.all(8.0),
                     child: Text('Note: Ensure printer is connected via OTG/USB and powered on.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                   ),
               ],
             ));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: Icon(
                  _selectedType == PrinterType.bluetooth ? Icons.bluetooth : Icons.usb, 
                  color: AppTheme.primary
                ),
                title: Text(device.name),
                subtitle: Text(device.address ?? 'No Address'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    _service.stopScan();
                    
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                    
                    try {
                      final success = await _service.connect(device, _selectedType);
                      if (context.mounted) Navigator.pop(context); // Close loading

                      if (context.mounted) {
                        if (success) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${device.name}'), backgroundColor: Colors.green));
                           Navigator.pop(context, device);
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Failed'), backgroundColor: Colors.red));
                        }
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context); 
                    }
                  },
                  child: const Text('Connect'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
