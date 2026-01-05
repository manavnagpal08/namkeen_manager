import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerName;
  final DateTime date;
  final double totalAmount;
  final List<OrderItem> items;
  final String status;
  final String paymentStatus; // New field
  final double gstPercentage;
  final double gstAmount;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.items,
    this.status = 'Created',
    this.paymentStatus = 'Unpaid', // Default
    this.gstPercentage = 0,
    this.gstAmount = 0,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,
      customerName: data['customer_name'] ?? 'Unknown',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (data['total_amount'] ?? 0).toDouble(),
      items: (data['items'] as List<dynamic>?)?.map((x) => OrderItem.fromMap(x)).toList() ?? [],
      status: data['status'] ?? 'Created',
      paymentStatus: data['payment_status'] ?? (data['status'] == 'Paid' ? 'Paid' : 'Unpaid'), // Migration fallback
      gstPercentage: (data['gst_percentage'] ?? 0).toDouble(),
      gstAmount: (data['gst_amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_name': customerName,
      'date': date,
      'total_amount': totalAmount,
      'items': items.map((x) => x.toMap()).toList(),
      'status': status,
      'payment_status': paymentStatus,
      'gst_percentage': gstPercentage,
      'gst_amount': gstAmount,
    };
  }
}

class OrderItem {
  final String productId;
  final String productName; // Snapshot
  final String sizeId;
  final String sizeName;    // Snapshot
  final double quantity;
  final double price;

  OrderItem({
    required this.productId, 
    required this.productName,
    required this.sizeId, 
    required this.sizeName,
    required this.quantity, 
    required this.price
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? data['product_id'] ?? 'Item',
      sizeId: data['size_id'] ?? '',
      sizeName: data['size_name'] ?? data['size_id'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      price: (data['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'size_id': sizeId,
      'size_name': sizeName,
      'quantity': quantity,
      'price': price,
    };
  }
}
