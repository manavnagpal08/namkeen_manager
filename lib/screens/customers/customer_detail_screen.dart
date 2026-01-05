import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../services/database_service.dart';
import '../../core/namkeen_theme.dart';
import 'package:intl/intl.dart';

class CustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.customer.name),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
               // Update Customer logic (TODO)
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Customer TODO')));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Balance Card Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                const Text('Total Due Amount', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                StreamBuilder<List<CustomerModel>>(
                  stream: db.getCustomers(), // Re-fetch to get live balance updates
                  builder: (context, snapshot) {
                     final current = snapshot.data?.firstWhere(
                       (c) => c.id == widget.customer.id, 
                       orElse: () => widget.customer
                     ) ?? widget.customer;

                     return Text(
                      '₹ ${current.totalDue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primary),
                      icon: const Icon(Icons.payment),
                      label: const Text('Receive Payment'),
                      onPressed: () => _showAddPaymentDialog(context),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                      icon: const Icon(Icons.history),
                      label: const Text('Send Reminder'),
                      onPressed: () {
                        // TODO: WhatsApp integration
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder Logic TODO')));
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
          
          ListTile(
            title: Text(widget.customer.phone),
            subtitle: Text(widget.customer.address),
            leading: const Icon(Icons.person_pin, color: AppTheme.primary),
          ),
          
          const Divider(),

          // Transactions Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Orders (Debit)'),
              Tab(text: 'Payments (Credit)'),
            ],
          ),

          Expanded(
            child: StreamBuilder<List<CustomerPaymentModel>>(
              stream: db.getCustomerPayments(widget.customer.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allTransactions = snapshot.data ?? [];
                
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionList(allTransactions, null),
                    _buildTransactionList(allTransactions, 'Credit'),
                    _buildTransactionList(allTransactions, 'Debit'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<CustomerPaymentModel> all, String? filterType) {
    // Note: Model uses 'Credit' for Order (Customer Debt Increases) and 'Debit' for Payment (Debt Decreases).
    // Or vice versa depending on perspective.
    // In DatabaseService.addPayment: 
    // "If 'Credit' (Order), Debt Increases (+ amount). If 'Debit' (Payment Received), Debt Decreases (- amount)"
    // So 'Credit' = Sales, 'Debit' = Received.

    final filtered = filterType == null ? all : all.where((t) => t.type == filterType).toList();

    if (filtered.isEmpty) {
      return Center(child: Text('No ${filterType?.toLowerCase() ?? ''} transactions found.', style: TextStyle(color: Colors.grey[400])));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isOrder = item.type == 'Credit'; // Order increases debt
        
        return Card(
          elevation: 0,
          color: isOrder ? Colors.red[50] : Colors.green[50], // Red for debt increase, Green for payment
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOrder ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
              child: Icon(
                isOrder ? Icons.shopping_cart : Icons.attach_money, 
                color: isOrder ? Colors.red : Colors.green
              ),
            ),
            title: Text(
              isOrder ? 'Order #${item.orderId ?? 'N/A'}' : 'Payment Received',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(item.date),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            trailing: Text(
              '${isOrder ? '+' : '-'} ₹${item.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16, 
                color: isOrder ? Colors.red : Colors.green
              ),
            ),
            onTap: () {
               // Show details?
            },
          ),
        );
      },
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Amount Received (₹)', prefixIcon: Icon(Icons.currency_rupee))
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl, 
              decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.note))
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (amountCtrl.text.isEmpty) return;
              
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;

              final payment = CustomerPaymentModel(
                id: '',
                customerId: widget.customer.id,
                amount: amount,
                type: 'Debit', // Payment Reduces Debt
                date: DateTime.now(),
                notes: noteCtrl.text,
              );

              await Provider.of<DatabaseService>(context, listen: false).addPayment(payment);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
