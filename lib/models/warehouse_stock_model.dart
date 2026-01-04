class WarehouseStockModel {
  final String id;
  final String productId;
  final String categoryId;
  final String sizeId;
  final String batchId;
  final String batchCode; // Human readable
  final double quantityPackets;
  final double quantityBoxes;
  final double quantityMasterCartons;
  final String warehouseUnitId; // e.g. "Rack-A1"
  final String storageAreaId;
  final String inchargeEmployeeId;
  final DateTime updatedAt;

  WarehouseStockModel({
    required this.id,
    required this.productId,
    required this.categoryId,
    required this.sizeId,
    required this.batchId,
    this.batchCode = '',
    required this.quantityPackets,
    required this.quantityBoxes,
    required this.quantityMasterCartons,
    required this.warehouseUnitId,
    required this.storageAreaId,
    required this.inchargeEmployeeId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'categoryId': categoryId,
      'sizeId': sizeId,
      'batchId': batchId,
      'batchCode': batchCode,
      'quantityPackets': quantityPackets,
      'quantityBoxes': quantityBoxes,
      'quantityMasterCartons': quantityMasterCartons,
      'warehouseUnitId': warehouseUnitId,
      'storageAreaId': storageAreaId,
      'inchargeEmployeeId': inchargeEmployeeId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WarehouseStockModel.fromMap(Map<String, dynamic> map, String id) {
    return WarehouseStockModel(
      id: id,
      productId: map['productId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      sizeId: map['sizeId'] ?? '',
      batchId: map['batchId'] ?? '',
      batchCode: map['batchCode'] ?? '', // Default to empty if missing
      quantityPackets: (map['quantityPackets'] ?? 0).toDouble(),
      quantityBoxes: (map['quantityBoxes'] ?? 0).toDouble(),
      quantityMasterCartons: (map['quantityMasterCartons'] ?? 0).toDouble(),
      warehouseUnitId: map['warehouseUnitId'] ?? '',
      storageAreaId: map['storageAreaId'] ?? '',
      inchargeEmployeeId: map['inchargeEmployeeId'] ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
