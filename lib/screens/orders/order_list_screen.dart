import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/namkeen_theme.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import 'receipt_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/company_settings_model.dart';

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

    return StreamBuilder<CompanySettingsModel>(
      stream: db.getCompanySettings(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? CompanySettingsModel.defaults();

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
                                DataCell(Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (order.status == 'Delivered' || order.status == 'Completed') ? Colors.green.shade100 : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Text(order.status, style: TextStyle(fontSize: 10, color: Colors.grey[800])),
                                    ),
                                    const SizedBox(height: 2),
                                    InkWell(
                                      onTap: () async {
                                         final newStatus = order.paymentStatus == 'Paid' ? 'Unpaid' : 'Paid';
                                         await db.updateOrderPaymentStatus(order.id, newStatus);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: order.paymentStatus == 'Paid' ? Colors.green : Colors.red,
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: Text(
                                          order.paymentStatus.toUpperCase(), 
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)
                                        ),
                                      ),
                                    ),
                                  ],
                                )),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.green, size: 20),
                                      tooltip: 'Send Reminder',
                                      onPressed: () async {
                                        final text = Uri.encodeComponent("Hello ${order.customerName},\nYour bill of ₹${order.totalAmount} (Order #${order.id.substring(0,4)}) is pending. Please pay at the earliest.\n- Namkeen Factory");
                                        final url = Uri.parse("https://wa.me/?text=$text");
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, color: Colors.blue, size: 20),
                                      tooltip: 'View Receipt',
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(order: order, settings: settings))),
                                    ),
                                  ],
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
      },
    );
  }
}
