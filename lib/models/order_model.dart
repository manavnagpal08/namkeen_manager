import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerName;
  final DateTime date;
  final double totalAmount;
  final List<OrderItem> items;
  final String status;
  final double gstPercentage;
  final double gstAmount;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.items,
    this.status = 'Created',
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
      'gst_percentage': gstPercentage,
      'gst_amount': gstAmount,
    };
  }
}

class OrderItem {
  final String productId;
  final String sizeId;
  final double quantity;
  final double price;

  OrderItem({required this.productId, required this.sizeId, required this.quantity, required this.price});

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['product_id'] ?? '',
      sizeId: data['size_id'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      price: (data['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'size_id': sizeId,
      'quantity': quantity,
      'price': price,
    };
  }
}
