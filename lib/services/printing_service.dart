import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../models/batch_model.dart';
import '../models/assignment_model.dart';
import '../models/employee_model.dart';
import '../models/company_settings_model.dart';

class PrintingService {
  PrinterManager get _printerManager => PrinterManager.instance;
  
  // Singleton-like access to the currently connected device
  static PrinterDevice? selectedDevice;
  static PrinterType? selectedPrinterType;

  // Scan for devices (Bluetooth or USB)
  // Note: For USB on Android, it requires OTG and permission.
  // Scan Stream Logic
  final StreamController<List<PrinterDevice>> _scanController = StreamController<List<PrinterDevice>>.broadcast();
  StreamSubscription? _scanSubscription;

  Stream<List<PrinterDevice>> get scanResults => _scanController.stream;

  Future<void> startScan(PrinterType type) async {
    _scanSubscription?.cancel();
    List<PrinterDevice> currentDevices = [];
    _scanController.add([]); 

    // discovery returns a Stream<PrinterDevice>
    _scanSubscription = _printerManager.discovery(type: type, isBle: false).listen((device) {
         // Basic de-duplication
         final alreadyExists = currentDevices.any((d) {
             if (d.address != null && device.address != null) {
                 return d.address == device.address;
             }
             return d.name == device.name;
         });

         if (!alreadyExists) {
             currentDevices.add(device);
             _scanController.add(List.from(currentDevices));
         }
    });
  }

  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // Connect
  Future<bool> connect(PrinterDevice device, PrinterType type) async {
    try {
      if (type == PrinterType.bluetooth) {
         await _printerManager.connect(
            type: type,
            model: BluetoothPrinterInput(
              name: device.name,
              address: device.address!,
              isBle: false,
              autoConnect: true
            ));
      } else if (type == PrinterType.usb) {
         await _printerManager.connect(
            type: type,
            model: UsbPrinterInput(
               name: device.name,
               productId: device.productId,
               vendorId: device.vendorId,
            ));
      }
      
      selectedDevice = device;
      selectedPrinterType = type;
      return true;
    } catch (e) {
      debugPrint('PrintingService Connect Error: $e');
      return false;
    }
  }

  // Disconnect
  Future<bool> disconnect() async {
    if (selectedPrinterType != null) {
      await _printerManager.disconnect(type: selectedPrinterType!);
      selectedDevice = null;
      selectedPrinterType = null;
      return true;
    }
    return false;
  }

  // Print Order (Thermal 58mm/80mm)
  Future<String> printOrderThermal(OrderModel order, CompanySettingsModel settings) async {
    if (selectedDevice == null || selectedPrinterType == null) {
       return "Printer not connected";
    }

    try {
      final profile = await CapabilityProfile.load();
      // Use settings preference for paper size if available
      final paperSize = settings.useThermal80mm ? '80mm' : '58mm';
      final generator = Generator(paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header & Logo
      if (settings.showLogo) {
          try {
             Uint8List? imageBytes;
             if (settings.logoBase64 != null && settings.logoBase64!.isNotEmpty) {
                 imageBytes = base64Decode(settings.logoBase64!);
             } else {
                 final byteData = await rootBundle.load('assets/images/logo.png');
                 imageBytes = byteData.buffer.asUint8List();
             }
             
             // imageBytes is definitely assigned above
             final img.Image? image = img.decodeImage(imageBytes);
             if (image != null) {
                 // Resize for thermal width - MINIMIZED LOGO
                 final resized = img.copyResize(image, width: paperSize == '80mm' ? 300 : 200); 
                 bytes += generator.image(resized);
                 bytes += generator.feed(1);
             }
          } catch (e) {
             debugPrint('Thermal Logo Error: $e');
          }
      }

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
      
      // GST Breakdown (Thermal)
      if (order.gstAmount > 0) {
        bytes += generator.text('Subtotal: Rs.${(order.totalAmount - order.gstAmount).toStringAsFixed(2)}', styles: const PosStyles(align: PosAlign.right));
        bytes += generator.text('GST (${settings.gstRate}%): Rs.${order.gstAmount.toStringAsFixed(2)}', styles: const PosStyles(align: PosAlign.right));
      }

      bytes += generator.text('Total: Rs.${order.totalAmount}',
          styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      
      bytes += generator.feed(1);
      bytes += generator.text('Customer: ${order.customerName}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text(settings.footerMessage, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('bill generated by FLIPCLIP system', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('9896817707', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send bytes via Manager
      _printerManager.send(type: selectedPrinterType!, bytes: bytes);
      return "Printed Successfully";
    } catch (e) {
      return "Error printing: $e";
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
                   if (logo != null) pw.Image(logo, height: 50),
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
                         pw.Text('GST (${settings.gstRate}%): Rs.${order.gstAmount.toStringAsFixed(2)}'),
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
                  pw.Text('bill generated by FLIPCLIP system 9896817707', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
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
