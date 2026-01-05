import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/namkeen_theme.dart';
import '../../models/order_model.dart';
import '../../services/printing_service.dart';
import '../../services/database_service.dart';
import '../../models/company_settings_model.dart';
import 'package:provider/provider.dart';

class ReceiptPreviewScreen extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onReturn;
  final PrintingService _printingService = PrintingService();

  ReceiptPreviewScreen({super.key, required this.order, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false); // We use stream below
    
    return StreamBuilder<CompanySettingsModel>(
      stream: db.getCompanySettings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final settings = snapshot.data ?? CompanySettingsModel.defaults();

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
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.showLogo) ...[
                          if (settings.logoBase64 != null)
                             Image.memory(base64Decode(settings.logoBase64!), height: 60)
                          else
                             Image.asset('assets/images/logo.png', height: 60, errorBuilder: (c,e,s) => const SizedBox.shrink()),
                          const SizedBox(height: 8),
                      ],
                      Text(settings.companyName.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      Text(settings.address, style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
                      Text('Ph: ${settings.phone} | GST: ${settings.gstNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      const Divider(height: 32),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Date: ${order.date.toIso8601String().substring(0,10)}'),
                        Text('Time: ${order.date.toIso8601String().substring(11,16)}'),
                      ]),
                      const SizedBox(height: 8),
                      Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(height: 32),
                      
                      // Items
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.productName)),
                            Text('${item.quantity.toInt()} x ', style: const TextStyle(color: Colors.grey)),
                            Text('Rs.${item.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                      
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Rs.${order.totalAmount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(height: 32),
                      Text(settings.footerMessage, style: const TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center), // This was visual
      // For thermal printer bytes:
      // bytes += generator.text(settings.footerMessage, styles: const PosStyles(align: PosAlign.center, bold: true)); // This line is commented out as it's not valid Flutter UI code here
                    ],
                  ),
                ),
              ),
            ),
          ),
            Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                    label: const Text('Print Invoice (PDF)'),
                    onPressed: () => _printingService.printOrderPDF(order, settings),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Print Thermal'),
                    onPressed: () async {
                       // Optional: Check connection first or let service handle
                       _printingService.printOrderThermal(order, settings);
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      );
      },
    );
  }
}
