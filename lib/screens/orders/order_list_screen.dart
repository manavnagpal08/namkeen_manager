import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/namkeen_theme.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import 'receipt_preview_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: db.getOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var orders = snapshot.data ?? [];
          if (_searchQuery.isNotEmpty) {
             orders = orders.where((o) => 
               o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
               o.id.contains(_searchQuery)
             ).toList();
          }
          
          // Sort
          orders.sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
               Padding(
                 padding: const EdgeInsets.all(16),
                 child: TextField(
                   decoration: InputDecoration(
                     hintText: 'Search Orders...',
                     prefixIcon: const Icon(Icons.search),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                     filled: true,
                     fillColor: Colors.grey.shade50,
                   ),
                   onChanged: (val) => setState(() => _searchQuery = val),
                 ),
               ),
               Expanded(
                 child: SingleChildScrollView(
                   scrollDirection: Axis.vertical,
                   child: SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: orders.map((order) {
                          return DataRow(cells: [
                            DataCell(Text(DateFormat('dd MMM yy').format(order.date), style: const TextStyle(fontSize: 13))),
                            DataCell(Text('#${order.id.length > 4 ? order.id.substring(0, 4).toUpperCase() : order.id}', style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
                            DataCell(Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text('₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: order.status == 'Paid' ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Text(order.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: order.status == 'Paid' ? Colors.green.shade800 : Colors.orange.shade800)),
                            )),
                            DataCell(IconButton(
                              icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                              tooltip: 'View Receipt',
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(order: order))),
                            )),
                          ]);
                        }).toList(),
                      ),
                   ),
                 ),
               ),
            ],
          );
        }
      ),
    );
  }
}
