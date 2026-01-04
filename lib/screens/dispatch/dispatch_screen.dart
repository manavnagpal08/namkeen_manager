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
      body: Column(
        children: [
          ExpansionTile(
            title: const Text('New Dispatch Entry'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(controller: _destCtrl, decoration: const InputDecoration(labelText: 'Destination')),
                    const SizedBox(height: 10),
                    TextField(controller: _transportCtrl, decoration: const InputDecoration(labelText: 'Transporter Name/Vehicle')),
                    const SizedBox(height: 10),
                    TextField(controller: _weightCtrl, decoration: const InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    ElevatedButton(
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
                        _destCtrl.clear(); _transportCtrl.clear(); _weightCtrl.clear();
                        setState(() {}); 
                      },
                      child: const Text('Log Dispatch'),
                    )
                  ],
                ),
              )
            ],
          ),
          Expanded(
            child: StreamBuilder<List<DispatchModel>>(
              stream: db.getDispatchLogs(),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      title: Text(log.destination),
                      subtitle: Text('${log.transporter} • ${log.weightKg}kg'),
                      trailing: Text(log.dispatchDate.toString().substring(0,10)),
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
