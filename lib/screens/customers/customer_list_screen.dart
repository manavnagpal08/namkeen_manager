import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../services/database_service.dart';
import '../../core/namkeen_theme.dart';
import 'customer_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger (Khata)'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
        onPressed: () => _showAddCustomerDialog(context),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Name or Phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CustomerModel>>(
              stream: db.getCustomers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = snapshot.data ?? [];
                
                // Filter
                final filtered = customers.where((c) {
                  return c.name.toLowerCase().contains(_searchQuery) || 
                         c.phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No customers found', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return _buildCustomerCard(customer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    final isDue = customer.totalDue > 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(customer: customer)
          ));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  customer.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(customer.phone, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
              
              // Balance & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${customer.totalDue.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDue ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    isDue ? 'Due' : 'Advance',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDue ? Colors.red[300] : Colors.green[300],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _launchPhone(customer.phone),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call, size: 18, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(url)) {
       // Handle error
    }
  }

  void _showAddCustomerDialog(BuildContext context) {
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
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              
              final newCustomer = CustomerModel(
                id: '', // Generated by Firestore
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                address: addressCtrl.text,
                totalDue: 0,
                lastTransactionDate: DateTime.now(),
              );

              await Provider.of<DatabaseService>(context, listen: false).addCustomer(newCustomer);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
