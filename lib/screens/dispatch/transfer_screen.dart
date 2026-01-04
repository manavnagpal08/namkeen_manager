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
      body: Column(
        children: [
          ExpansionTile(
            title: const Text('Create Transfer Challan'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(controller: _materialCtrl, decoration: const InputDecoration(labelText: 'Material Name')),
                    const SizedBox(height: 10),
                    TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'From'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'To'))),
                    ]),
                    const SizedBox(height: 10),
                    ElevatedButton(
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
                        _materialCtrl.clear(); _qtyCtrl.clear(); _toCtrl.clear();
                        setState(() {}); 
                      },
                      child: const Text('Generate Challan'),
                    )
                  ],
                ),
              )
            ],
          ),
          Expanded(
            child: StreamBuilder<List<TransferModel>>(
              stream: db.getTransfers(),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      leading: const Icon(Icons.transfer_within_a_station),
                      title: Text('${log.materialName} (${log.quantity})'),
                      subtitle: Text('${log.fromLocation} -> ${log.toLocation}'),
                      trailing: Text(log.transferDate.toString().substring(0,10)),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
