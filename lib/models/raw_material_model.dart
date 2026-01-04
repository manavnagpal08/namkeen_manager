class RawMaterialModel {
  final String id;
  final String name;
  final String unit;
  final String category;
  final double currentStock;
  final double costPerUnit;
  final double minimumThreshold;
  final String supplierName;
  final String storageLocation;
  final DateTime assignedDate;
  final DateTime? expiryDate; // New field

  RawMaterialModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.currentStock,
    required this.minimumThreshold,
    required this.costPerUnit,
    required this.supplierName,
    required this.storageLocation,
    required this.assignedDate,
    this.expiryDate,
  });

  factory RawMaterialModel.fromMap(String id, Map<String, dynamic> data) {
    return RawMaterialModel(
      id: id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'kg',
      category: data['category'] ?? 'General',
      currentStock: (data['currentStock'] ?? 0).toDouble(),
      minimumThreshold: (data['minimumThreshold'] ?? 0).toDouble(),
      costPerUnit: (data['costPerUnit'] ?? 0).toDouble(),
      supplierName: data['supplierName'] ?? '',
      storageLocation: data['storageLocation'] ?? '',
      assignedDate: (data['assignedDate'] as dynamic)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'category': category,
      'currentStock': currentStock,
      'minimumThreshold': minimumThreshold,
      'costPerUnit': costPerUnit,
      'supplierName': supplierName,
      'storageLocation': storageLocation,
      'assignedDate': assignedDate,
      'expiryDate': expiryDate,
    };
  }
}
