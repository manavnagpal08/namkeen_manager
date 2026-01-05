import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../services/database_service.dart';
import '../../core/namkeen_theme.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger (Khata)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            onPressed: () => _showAddCustomerDialog(context, db),
            tooltip: 'Add New Customer',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search Customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50], 
              ),
              onChanged: (val) => setState(() => _search = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CustomerModel>>(
              stream: db.getCustomers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final all = snapshot.data ?? [];
                final filtered = all.where((c) => c.name.toLowerCase().contains(_search) || c.phone.contains(_search)).toList();

                if (filtered.isEmpty) return const Center(child: Text('No customers found.'));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer))),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(customer.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ),
                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(customer.phone),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${customer.totalDue.toStringAsFixed(0)}', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                color: customer.totalDue > 0 ? Colors.red : Colors.green
                              )
                            ),
                            Text(
                              customer.totalDue > 0 ? 'Due' : 'Advance', 
                              style: const TextStyle(fontSize: 10, color: Colors.grey)
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, DatabaseService db) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', icon: Icon(Icons.person))),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', icon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', icon: Icon(Icons.location_on))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final newCust = CustomerModel(
                id: '', 
                name: nameCtrl.text, 
                phone: phoneCtrl.text, 
                address: addressCtrl.text, 
                totalDue: 0, 
                lastTransactionDate: DateTime.now()
              );
              await db.addCustomer(newCust);
              if (context.mounted) Navigator.pop(context);
            }, 
            child: const Text('Add Customer')
          ),
        ],
      ),
    );
  }
}
