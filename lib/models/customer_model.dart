import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double totalDue;
  final DateTime lastTransactionDate;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.totalDue,
    required this.lastTransactionDate,
  });

  factory CustomerModel.fromMap(String id, Map<String, dynamic> data) {
    return CustomerModel(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      totalDue: (data['totalDue'] ?? 0).toDouble(),
      lastTransactionDate: (data['lastTransactionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'totalDue': totalDue,
      'lastTransactionDate': lastTransactionDate,
    };
  }
}

class CustomerPaymentModel {
  final String id;
  final String customerId;
  final double amount;
  final String type; // 'Credit' (Order) or 'Debit' (Payment)
  final DateTime date;
  final String? orderId;
  final String notes;

  CustomerPaymentModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.date,
    this.orderId,
    this.notes = '',
  });

  factory CustomerPaymentModel.fromMap(String id, Map<String, dynamic> data) {
    return CustomerPaymentModel(
      id: id,
      customerId: data['customerId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'Credit',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderId: data['orderId'],
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'amount': amount,
      'type': type,
      'date': date,
      'orderId': orderId,
      'notes': notes,
    };
  }
}
