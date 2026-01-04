import 'package:cloud_firestore/cloud_firestore.dart';

class BatchModel {
  final String id;
  final String batchCode; // Display ID e.g. B-1001
  final String productId;
  final String sizeId; // Batch size usually matches a bulk size or is custom
  final double targetQuantityKg;
  final String status; // Planned, In Progress, Completed
  final DateTime startTime;
  final DateTime? endTime;
  final String recipeId; // Specific recipe used
  final double packedQuantityKg; // Qty moved to packaging/warehouse
  
  // Missing fields fixed
  final String supervisorId;
  final double producedQuantityKg;
  final double wastageKg;

  BatchModel({
    required this.id,
    required this.batchCode,
    required this.productId,
    required this.sizeId,
    required this.targetQuantityKg,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.supervisorId,
    this.producedQuantityKg = 0.0,
    this.wastageKg = 0.0,
    this.recipeId = '',
    this.packedQuantityKg = 0.0,
  });

  factory BatchModel.fromMap(String id, Map<String, dynamic> data) {
    return BatchModel(
      id: id,
      batchCode: data['batch_code'] ?? '',
      productId: data['product_id'] ?? '',
      sizeId: data['size_id'] ?? '',
      targetQuantityKg: (data['target_quantity_kg'] ?? 0).toDouble(),
      status: data['status'] ?? 'Planned',
      startTime: (data['start_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['end_time'] as Timestamp?)?.toDate(),
      supervisorId: data['supervisor_id'] ?? '',
      producedQuantityKg: (data['produced_quantity_kg'] ?? 0).toDouble(),
      wastageKg: (data['wastage_kg'] ?? 0).toDouble(),
      recipeId: data['recipe_id'] ?? '',
      packedQuantityKg: (data['packed_quantity_kg'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batch_code': batchCode,
      'product_id': productId,
      'size_id': sizeId,
      'target_quantity_kg': targetQuantityKg,
      'status': status,
      'start_time': startTime,
      'end_time': endTime,
      'supervisor_id': supervisorId,
      'produced_quantity_kg': producedQuantityKg,
      'wastage_kg': wastageKg,
      'recipe_id': recipeId,
      'packed_quantity_kg': packedQuantityKg,
    };
  }
  BatchModel copyWith({
    String? id,
    String? batchCode,
    String? productId,
    String? sizeId,
    double? targetQuantityKg,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    String? supervisorId,
    double? producedQuantityKg,
    double? wastageKg,
    String? recipeId,
    double? packedQuantityKg,
  }) {
    return BatchModel(
      id: id ?? this.id,
      batchCode: batchCode ?? this.batchCode,
      productId: productId ?? this.productId,
      sizeId: sizeId ?? this.sizeId,
      targetQuantityKg: targetQuantityKg ?? this.targetQuantityKg,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      supervisorId: supervisorId ?? this.supervisorId,
      wastageKg: wastageKg ?? this.wastageKg,
      recipeId: recipeId ?? this.recipeId,
      packedQuantityKg: packedQuantityKg ?? this.packedQuantityKg,
    );
  }
}
