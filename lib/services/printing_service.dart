import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import '../models/order_model.dart';
import '../models/batch_model.dart';
import '../models/assignment_model.dart';
import '../models/employee_model.dart';
import '../models/company_settings_model.dart';

class PrintingService {
  // Check permission
  Future<bool> checkPermission() async {
    return await PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  // Get Bonded Devices
  Future<List<BluetoothInfo>> getBondedDevices() async {
    if (kIsWeb) return []; 
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // Connect to device
  Future<bool> connect(String macAddress) async {
    if (kIsWeb) return false;
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  // Disconnect
  Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }

  // Print Order (Thermal 58mm/80mm)
  Future<void> printOrderThermal(OrderModel order, CompanySettingsModel settings) async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (isConnected) {
      final profile = await CapabilityProfile.load();
      // Use settings preference for paper size if available
      final paperSize = settings.useThermal80mm ? '80mm' : '58mm';
      final generator = Generator(paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text(settings.companyName.toUpperCase(),
          styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      bytes += generator.text(settings.address, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Ph: ${settings.phone}', styles: const PosStyles(align: PosAlign.center));
      if (settings.gstNumber.isNotEmpty) {
        bytes += generator.text('GSTIN: ${settings.gstNumber}', styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.feed(1);
      bytes += generator.text('Date: ${order.date.toIso8601String().substring(0, 10)}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Time: ${order.date.toIso8601String().substring(11, 16)}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      // Items
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Price', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      
      for (var item in order.items) {
         bytes += generator.row([
           PosColumn(text: item.productName, width: 6),
           PosColumn(text: '${item.quantity.toInt()}', width: 2),
           PosColumn(text: '${item.price}', width: 4, styles: PosStyles(align: PosAlign.right)),
         ]);
      }

      bytes += generator.hr();
      bytes += generator.text('Total: Rs.${order.totalAmount}',
          styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      
      bytes += generator.feed(1);
      bytes += generator.text('Customer: ${order.customerName}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send bytes
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  // A4 PDF Invoice for Order
  Future<void> printOrderPDF(OrderModel order, CompanySettingsModel settings) async {
    final pdf = pw.Document();
    
    // Load Logo Logic
    pw.ImageProvider? logo;
    if (settings.showLogo) {
      if (settings.logoBase64 != null && settings.logoBase64!.isNotEmpty) {
        try {
           final bytes = base64Decode(settings.logoBase64!);
           logo = pw.MemoryImage(bytes);
        } catch (e) {
           debugPrint('Error decoding base64 logo: $e');
        }
      }
      
      // Fallback to asset
      if (logo == null) {
        try {
          logo = await imageFromAssetBundle('assets/images/logo.png');
        } catch (e) {
          debugPrint('Error loading asset logo: $e');
        }
      }
    }

    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   if (logo != null) pw.Image(logo, width: 80, height: 80),
                   pw.Expanded(
                     child: pw.Column(
                       crossAxisAlignment: pw.CrossAxisAlignment.end,
                       children: [
                         pw.Text(settings.companyName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                         pw.Text(settings.address, textAlign: pw.TextAlign.right),
                         pw.Text('Phone: ${settings.phone}', textAlign: pw.TextAlign.right),
                         if (settings.gstNumber.isNotEmpty)
                           pw.Text('GSTIN: ${settings.gstNumber}', textAlign: pw.TextAlign.right),
                       ]
                     )
                   )
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              // Invoice Info & Customer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INVOICE TO:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                      pw.Text(order.customerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE NO: #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id}'),
                      pw.Text('DATE: ${order.date.toIso8601String().substring(0, 10)}'),
                      pw.Text('STATUS: ${order.status.toUpperCase()}', style: pw.TextStyle(color: order.status == 'Paid' ? PdfColors.green : PdfColors.orange)),
                    ]
                  )
                ]
              ),
              
              pw.SizedBox(height: 20),
              
              // Table
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Rate', 'Total'],
                data: order.items.map((item) => [
                  item.productName,
                  '${item.quantity}',
                  'Rs.${item.price}',
                  'Rs.${(item.quantity * item.price).toStringAsFixed(2)}',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
              
              pw.SizedBox(height: 20),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                       pw.Text('Subtotal: Rs.${(order.totalAmount - order.gstAmount).toStringAsFixed(2)}'),
                       if (order.gstAmount > 0)
                         pw.Text('GST (12%): Rs.${order.gstAmount.toStringAsFixed(2)}'),
                       pw.SizedBox(height: 4),
                       pw.Text('GRAND TOTAL: Rs.${order.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ]
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Divider(),
              if (settings.footerMessage.isNotEmpty)
                pw.Center(child: pw.Text(settings.footerMessage, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
                
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('Powered by FLIP CLIP', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ]
              )
            ],
          );
        },
      ),
    );

    // Print
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  // A4 PDF Print for Batch Report (Detailed)
  Future<void> printBatchReport(BatchModel batch, List<AssignmentModel> assignments, List<EmployeeModel> employees) async {
    final pdf = pw.Document();

    // Helper to get employee name
    String getEmpName(String id) => employees.firstWhere((e) => e.id == id, orElse: () => EmployeeModel(id: '', name: 'Unknown', role: '', phone: '', salary: 0, baseSalary: 0, address: '')).name;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(children: [
                       // Logo placeholder if needed, usually we pass imageprovider
                       pw.Text('Batch Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Text('Date: ${batch.startTime.toIso8601String().substring(0,10)}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                   pw.Expanded(
                     child: pw.Column(
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       children: [
                          pw.Text('Batch Code: ${batch.batchCode}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Product: ${batch.productId}'),
                          pw.Text('Status: ${batch.status}'), 
                       ]
                     )
                   ),
                   pw.Expanded(
                     child: pw.Column(
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       children: [
                          pw.Text('Target: ${batch.targetQuantityKg} kg'),
                          pw.Text('Produced: ${batch.producedQuantityKg} kg'),
                          pw.Text('Wastage: ${batch.wastageKg} kg'), 
                       ]
                     )
                   ),
                ]
              ),
              
              pw.Divider(),
              pw.Text('Raw Materials Used', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              if (assignments.any((a) => a.materialsUsed.isNotEmpty))
                pw.TableHelper.fromTextArray(
                  headers: ['Material', 'Source (Location)', 'Quantity', 'assignment'],
                  data: assignments.expand((a) => a.materialsUsed.map((m) => [
                    m['name'] ?? 'Unknown',
                    m['source'] ?? 'N/A',
                    '${m['quantity']} kg',
                     a.type
                  ])).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                )
              else
                 pw.Text('No raw materials recorded for this batch.'),

              pw.SizedBox(height: 20),
              
              pw.Divider(),
              pw.Text('Packaging & Labor Log', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              
              if (assignments.isEmpty)
                pw.Text('No packaging tasks recorded.')
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Employee', 'Task', 'Target', 'Completed', 'Status'],
                  data: assignments.map((a) => [
                    getEmpName(a.employeeId),
                    a.type,
                    '${a.targetQuantity}',
                    '${a.completedUnits}',
                    a.status
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                ),

              pw.Spacer(),
              pw.Text('Generated by Factory Manager', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  // Analytics Report (Monthly Summary)
  Future<void> printAnalyticsReport({
    required int lowStockCount, 
    required int activeBatches, 
    required int finishedGoodsCount,
    required double totalOrdersValue 
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Factory Status Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${DateTime.now().toIso8601String().substring(0, 10)}'),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              pw.Text('Key Performance Indicators', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              
              pw.TableHelper.fromTextArray(
                data: <List<String>>[
                  <String>['Metric', 'Value', 'Status'],
                  <String>['Active Batches', '$activeBatches', 'Production'],
                  <String>['Low Stock Items', '$lowStockCount', lowStockCount > 0 ? 'Action Needed' : 'Healthy'],
                  <String>['Finished Goods Lots', '$finishedGoodsCount', 'In Warehouse'],
                  <String>['Total Orders Value', 'Rs. $totalOrdersValue', 'Revenue'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),
              
              pw.SizedBox(height: 30),
              pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 50),
              pw.Divider(borderStyle: pw.BorderStyle.dotted),
              pw.Text('Manager Signature'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}
