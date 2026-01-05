import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/customer_model.dart';
import '../../services/database_service.dart';
import '../../core/namkeen_theme.dart';

class CustomerDetailScreen extends StatelessWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit Customer Dialog
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Balance Card
          _buildBalanceCard(context, db),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft, 
              child: Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<CustomerPaymentModel>>(
              stream: db.getCustomerPayments(customer.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final logs = snapshot.data ?? [];
                
                if (logs.isEmpty) {
                  return const Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isCredit = log.type == 'Credit'; // Order (Adding to Debt)
                    
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          child: Icon(
                            isCredit ? Icons.shopping_bag : Icons.attach_money, 
                            color: isCredit ? Colors.red : Colors.green,
                            size: 18
                          ),
                        ),
                        title: Text(isCredit ? 'Order via POS' : 'Payment Received'),
                        subtitle: Text(DateFormat.yMMMd().add_jm().format(log.date)),
                        trailing: Text(
                          '${isCredit ? '+' : '-'} ₹${log.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isCredit ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(context, db),
        label: const Text('Receive Payment'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, DatabaseService db) {
    // We retrieve the latest customer object from stream to ensure balance updates dynamically
    return StreamBuilder<List<CustomerModel>>(
      stream: db.getCustomers(), // Not efficient but works for now. Better to get single doc stream.
      builder: (context, snapshot) {
        final freshCustomer = snapshot.data?.firstWhere((c) => c.id == customer.id, orElse: () => customer) ?? customer;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            children: [
              const Text('Current Balance Due', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '₹${freshCustomer.totalDue.toStringAsFixed(0)}', 
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Text(
                'Last Transaction: ${DateFormat.yMMMd().format(freshCustomer.lastTransactionDate)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (freshCustomer.phone.isNotEmpty)
                ActionChip(
                  label: Text('Call ${freshCustomer.phone}'),
                  avatar: const Icon(Icons.call, size: 16),
                  onPressed: () {
                    // Launch dialer
                  },
                  backgroundColor: Colors.white,
                )
            ],
          ),
        );
      }
    );
  }

  void _showAddPaymentDialog(BuildContext context, DatabaseService db) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receive Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Received (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  if (amountCtrl.text.isEmpty) return;
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0) return;

                  final payment = CustomerPaymentModel(
                    id: '', 
                    customerId: customer.id, 
                    amount: amount, 
                    type: 'Debit', 
                    date: DateTime.now(), 
                    notes: noteCtrl.text
                  );

                  await db.addPayment(payment);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Confirm Payment', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
