class PackingUnitModel {
  final String id;
  final String categoryId;
  final String sizeId;
  final int packetsPerBox;
  final int boxesPerMasterCarton;
  final int masterCartonsPerWarehouseUnit;
  final DateTime updatedAt;

  PackingUnitModel({
    required this.id,
    required this.categoryId,
    required this.sizeId,
    required this.packetsPerBox,
    required this.boxesPerMasterCarton,
    required this.masterCartonsPerWarehouseUnit,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'sizeId': sizeId,
      'packetsPerBox': packetsPerBox,
      'boxesPerMasterCarton': boxesPerMasterCarton,
      'masterCartonsPerWarehouseUnit': masterCartonsPerWarehouseUnit,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PackingUnitModel.fromMap(Map<String, dynamic> map, String id) {
    return PackingUnitModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      sizeId: map['sizeId'] ?? '',
      packetsPerBox: map['packetsPerBox']?.toInt() ?? 1,
      boxesPerMasterCarton: map['boxesPerMasterCarton']?.toInt() ?? 1,
      masterCartonsPerWarehouseUnit: map['masterCartonsPerWarehouseUnit']?.toInt() ?? 1,
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
