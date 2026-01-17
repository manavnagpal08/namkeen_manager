import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/namkeen_theme.dart';
import '../../models/order_model.dart';
import '../../services/printing_service.dart';
import '../../services/database_service.dart';
import '../settings/printer_scan_screen.dart'; // Re-added for connection handling
import '../../models/company_settings_model.dart';
import 'package:provider/provider.dart';

class ReceiptPreviewScreen extends StatelessWidget {
  final OrderModel order;
  final CompanySettingsModel settings;
  final VoidCallback? onReturn;
  final PrintingService _printingService = PrintingService();

  ReceiptPreviewScreen({
    super.key, 
    required this.order, 
    required this.settings,
    this.onReturn
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('ReceiptPreviewScreen: Building for Order ${order.id}');
    debugPrint('ReceiptPreviewScreen: Settings found: ${settings.companyName}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: onReturn != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onReturn)
          : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (settings.showLogo && settings.logoBase64 != null && settings.logoBase64!.isNotEmpty)
                            Builder(
                              builder: (context) {
                                try {
                                  return Image.memory(
                                    base64Decode(settings.logoBase64!),
                                    height: 50, // Minimized
                                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                                  );
                                } catch (e) {
                                  return const SizedBox.shrink();
                                }
                              },
                            )
                          else if (settings.showLogo)
                             Image.asset('assets/images/logo.png', height: 50, errorBuilder: (c,e,s) => const SizedBox.shrink()),
                          
                          const SizedBox(height: 12),
                          Text(settings.companyName.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2), textAlign: TextAlign.center),
                          const SizedBox(height: 2),
                          Text(settings.address, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                          Text('Ph: ${settings.phone} | GST: ${settings.gstNumber}', style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1),
                          ),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Date: ${DateFormat('dd/MM/yyyy').format(order.date)}', style: const TextStyle(fontSize: 11)),
                            Text('Time: ${DateFormat('HH:mm').format(order.date)}', style: const TextStyle(fontSize: 11)),
                          ]),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          
                          // Items Header
                          const Row(
                            children: [
                              Expanded(child: Text('PRODUCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                              SizedBox(width: 40, child: Text('QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center)),
                              SizedBox(width: 80, child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.right)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Items
                          ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                SizedBox(width: 40, child: Text(item.quantity.toInt().toString(), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                SizedBox(width: 80, child: Text('₹${(item.quantity * item.price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                              ],
                            ),
                          )),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, thickness: 1),
                          ),
                          // GST Breakdown
                          if (order.gstAmount > 0) ...[
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 const Text('Subtotal', style: TextStyle(fontSize: 13)),
                                 Text('₹${(order.totalAmount - order.gstAmount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                               ],
                             ),
                             const SizedBox(height: 4),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text('GST (${settings.gstRate}%)', style: const TextStyle(fontSize: 13)),
                                 Text('₹${order.gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                               ],
                             ),
                             const SizedBox(height: 12),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL AMOUNT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text('₹${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(settings.footerMessage, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          const Text('bill generated by FLIPCLIP system 9896817707', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
            Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: const Text('Download PDF'),
                    onPressed: () => _printingService.printOrderPDF(order, settings),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.print),
                      label: const Text('Print Receipt'),
                      onPressed: () async {
                         final status = await _printingService.printOrderThermal(order, settings);
                         if (context.mounted) {
                            if (status == "Printer not connected") {
                               showDialog(
                                 context: context,
                                 builder: (ctx) => AlertDialog(
                                   title: const Text('Printer Disconnected'),
                                   content: const Text('No thermal printer connected. Configure now?'),
                                   actions: [
                                     TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                     ElevatedButton(
                                       onPressed: () {
                                         Navigator.pop(ctx);
                                         Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterScanScreen()));
                                       }, 
                                       child: const Text('Connect Printer')
                                     )
                                   ],
                                 )
                               );
                            } else if (status.startsWith("Error")) {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status), backgroundColor: Colors.red));
                            } else {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status), backgroundColor: Colors.green));
                            }
                         }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Debug Info Section
          if (true) // Toggle this or set to kDebugMode if preferred
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ExpansionTile(
                title: const Text('Debug Info', style: TextStyle(fontSize: 12, color: Colors.grey)),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade100,
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ID: ${order.id}'),
                        Text('Customer: ${order.customerName}'),
                        Text('Items count: ${order.items.length}'),
                        Text('Total: ${order.totalAmount}'),
                        Text('Settings Company: ${settings.companyName}'),
                        Text('Logo Present: ${settings.logoBase64?.isNotEmpty == true}'),
                        Text('isWeb: $kIsWeb'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
