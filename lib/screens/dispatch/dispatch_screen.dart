import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/dispatch_transfer_models.dart';
import '../../services/database_service.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final _destCtrl = TextEditingController();
  final _transportCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch Logs'), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Entry Form
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column( // Or Row
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Dispatch Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(width: 200, child: TextField(controller: _destCtrl, decoration: const InputDecoration(labelText: 'Destination', isDense: true, border: OutlineInputBorder()))),
                        SizedBox(width: 200, child: TextField(controller: _transportCtrl, decoration: const InputDecoration(labelText: 'Transporter / Vehicle', isDense: true, border: OutlineInputBorder()))),
                        SizedBox(width: 120, child: TextField(controller: _weightCtrl, decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), 
                            backgroundColor: AppTheme.primary, 
                            foregroundColor: Colors.white
                          ),
                          onPressed: () async {
                            if (_destCtrl.text.isEmpty) return;
                            final d = DispatchModel(
                              id: '',
                              batchId: 'MANUAL',
                              destination: _destCtrl.text,
                              transporter: _transportCtrl.text,
                              weightKg: double.tryParse(_weightCtrl.text) ?? 0,
                              dispatchDate: DateTime.now(),
                            );
                            await db.addDispatch(d);
                            
                            if (mounted) {
                              _destCtrl.clear(); _transportCtrl.clear(); _weightCtrl.clear();
                              setState(() {}); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispatch Logged')));
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('ADD LOG'),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: StreamBuilder<List<DispatchModel>>(
                  stream: db.getDispatchLogs(),
                  builder: (context, snapshot) {
                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) return const Center(child: Text('No Dispatch Logs Found'));

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                         child: ConstrainedBox(
                           constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
                           child: DataTable(
                             columnSpacing: 24,
                             headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                             columns: const [
                               DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('DESTINATION', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('TRANSPORTER', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('WEIGHT (KG)', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('BATCH', style: TextStyle(fontWeight: FontWeight.bold))),
                             ],
                             rows: logs.map((log) {
                               return DataRow(cells: [
                                 DataCell(Text(log.dispatchDate.toString().substring(0, 10))),
                                 DataCell(Text(log.destination, style: const TextStyle(fontWeight: FontWeight.w500))),
                                 DataCell(Text(log.transporter)),
                                 DataCell(Text(log.weightKg.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                                 DataCell(Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                   decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                   child: Text(log.batchId, style: const TextStyle(fontSize: 11)),
                                 )),
                               ]);
                             }).toList(),
                           ),
                         ),
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
