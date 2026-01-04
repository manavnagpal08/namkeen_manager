class DispatchModel {
  final String id;
  final String batchId; // Optional, or Order ID
  final String destination;
  final String transporter;
  final double weightKg;
  final DateTime dispatchDate;

  DispatchModel({
    required this.id,
    required this.batchId,
    required this.destination,
    required this.transporter,
    required this.weightKg,
    required this.dispatchDate,
  });

  Map<String, dynamic> toMap() => {
    'batch_id': batchId,
    'destination': destination,
    'transporter': transporter,
    'weight_kg': weightKg,
    'dispatch_date': dispatchDate,
  };

  factory DispatchModel.fromMap(String id, Map<String, dynamic> data) => DispatchModel(
    id: id,
    batchId: data['batch_id'] ?? '',
    destination: data['destination'] ?? '',
    transporter: data['transporter'] ?? '',
    weightKg: (data['weight_kg'] ?? 0).toDouble(),
    dispatchDate: (data['dispatch_date'] as dynamic)?.toDate() ?? DateTime.now(),
  );
}

class TransferModel {
  final String id;
  final String materialName;
  final double quantity;
  final String fromLocation;
  final String toLocation;
  final DateTime transferDate;
  final String employeeId;

  TransferModel({
    required this.id,
    required this.materialName,
    required this.quantity,
    required this.fromLocation,
    required this.toLocation,
    required this.transferDate,
    required this.employeeId,
  });

  Map<String, dynamic> toMap() => {
    'material_name': materialName,
    'quantity': quantity,
    'from_location': fromLocation,
    'to_location': toLocation,
    'transfer_date': transferDate,
    'employee_id': employeeId,
  };

  factory TransferModel.fromMap(String id, Map<String, dynamic> data) => TransferModel(
    id: id,
    materialName: data['material_name'] ?? '',
    quantity: (data['quantity'] ?? 0).toDouble(),
    fromLocation: data['from_location'] ?? '',
    toLocation: data['to_location'] ?? '',
    transferDate: (data['transfer_date'] as dynamic)?.toDate() ?? DateTime.now(),
    employeeId: data['employee_id'] ?? '',
  );
}
