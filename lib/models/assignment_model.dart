import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentModel {
  final String id;
  final String batchId;
  final String batchCode; // Added for display
  final String employeeId;
  final String type; // manufacturing, packaging
  final double completedUnits;
  final String status; // Pending, In Progress, Completed
  final DateTime assignedAt;
  final DateTime? completedAt;
  final double targetQuantity; // kg or packets
  final List<Map<String, dynamic>> materialsUsed; // List of {name, source, quantity}

  AssignmentModel({
    required this.id,
    required this.batchId,
    this.batchCode = '',
    required this.employeeId,
    required this.type,
    required this.targetQuantity,
    this.completedUnits = 0,
    this.status = 'Pending',
    required this.assignedAt,
    this.completedAt,
    this.materialsUsed = const [],
  });

  factory AssignmentModel.fromMap(String id, Map<String, dynamic> data) {
    return AssignmentModel(
      id: id,
      batchId: data['batch_id'] ?? '',
      batchCode: data['batch_code'] ?? '',
      employeeId: data['employee_id'] ?? '',
      type: data['type'] ?? '',
      targetQuantity: (data['target_quantity'] ?? 0).toDouble(),
      completedUnits: (data['completed_units'] ?? 0).toDouble(),
      status: data['status'] ?? 'Pending',
      assignedAt: (data['assigned_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      materialsUsed: List<Map<String, dynamic>>.from(data['materials_used'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batch_id': batchId,
      'batch_code': batchCode,
      'employee_id': employeeId,
      'type': type,
      'target_quantity': targetQuantity,
      'completed_units': completedUnits,
      'status': status,
      'assigned_at': assignedAt,
      'completed_at': completedAt,
      'materials_used': materialsUsed,
    };
  }

  AssignmentModel copyWith({
    String? id,
    String? batchId,
    String? employeeId,
    String? type,
    double? targetQuantity,
    double? completedUnits,
    String? status,
    DateTime? assignedAt,
    DateTime? completedAt,
    List<Map<String, dynamic>>? materialsUsed,
  }) {
    return AssignmentModel(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      employeeId: employeeId ?? this.employeeId,
      type: type ?? this.type,
      targetQuantity: targetQuantity ?? this.targetQuantity,
      completedUnits: completedUnits ?? this.completedUnits,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      materialsUsed: materialsUsed ?? this.materialsUsed,
    );
  }
}
