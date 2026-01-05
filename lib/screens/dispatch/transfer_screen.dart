import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/dispatch_transfer_models.dart';
import '../../services/database_service.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _materialCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _fromCtrl = TextEditingController(text: 'Main Storage');
  final _toCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Material Transfer Challan'), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             // Compact Form
             Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text('New Transfer Challan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       const SizedBox(height: 12),
                       Wrap(
                         spacing: 12,
                         runSpacing: 12,
                         crossAxisAlignment: WrapCrossAlignment.center,
                         children: [
                           SizedBox(width: 200, child: TextField(controller: _materialCtrl, decoration: const InputDecoration(labelText: 'Material Name', isDense: true, border: OutlineInputBorder()))),
                           SizedBox(width: 100, child: TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                           SizedBox(width: 140, child: TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'From', isDense: true, border: OutlineInputBorder()))),
                           const Icon(Icons.arrow_forward, color: Colors.grey),
                           SizedBox(width: 140, child: TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'To', isDense: true, border: OutlineInputBorder()))),
                           ElevatedButton.icon(
                             style: ElevatedButton.styleFrom(
                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), 
                               backgroundColor: AppTheme.primary, 
                               foregroundColor: Colors.white
                             ),
                             onPressed: () async {
                              if (_materialCtrl.text.isEmpty) return;
                              final t = TransferModel(
                                id: '',
                                materialName: _materialCtrl.text,
                                quantity: double.tryParse(_qtyCtrl.text) ?? 0,
                                fromLocation: _fromCtrl.text,
                                toLocation: _toCtrl.text,
                                transferDate: DateTime.now(),
                                employeeId: 'ADMIN',
                              );
                              await db.addTransfer(t);

                              if (mounted) {
                                _materialCtrl.clear(); _qtyCtrl.clear(); _toCtrl.clear();
                                setState(() {}); 
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challan Generated')));
                              }
                             },
                             icon: const Icon(Icons.compare_arrows),
                             label: const Text('TRANSFER'),
                           )
                         ]
                       )
                    ]
                  )
                )
             ),
             const SizedBox(height: 16),
             Expanded(
               child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: StreamBuilder<List<TransferModel>>(
                  stream: db.getTransfers(),
                  builder: (context, snapshot) {
                     final logs = snapshot.data ?? [];
                     if (logs.isEmpty) return const Center(child: Text('No Transfers Found'));
                     
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
                               DataColumn(label: Text('MATERIAL', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('FLOW', style: TextStyle(fontWeight: FontWeight.bold))),
                               DataColumn(label: Text('BY', style: TextStyle(fontWeight: FontWeight.bold))),
                             ],
                             rows: logs.map((log) {
                               return DataRow(cells: [
                                 DataCell(Text(log.transferDate.toString().substring(0, 10))),
                                 DataCell(Text(log.materialName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                 DataCell(Text(log.quantity.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                                 DataCell(Row(children: [
                                    Text(log.fromLocation, style: const TextStyle(color: Colors.grey)),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey)),
                                    Text(log.toLocation, style: const TextStyle(fontWeight: FontWeight.w500)),
                                 ])),
                                 DataCell(Text(log.employeeId, style: const TextStyle(fontSize: 12))),
                               ]);
                             }).toList(),
                           ),
                         ),
                       ),
                     );
                  }
                )
               )
             )
          ],
        ),
      ),
    );
  }
}
