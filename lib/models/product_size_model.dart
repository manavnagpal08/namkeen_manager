class ProductSizeModel {
  final String id;
  final String categoryId;
  final String label;
  final double weightInGrams;
  final bool isBulk;

  ProductSizeModel({
    required this.id,
    required this.categoryId,
    required this.label,
    required this.weightInGrams,
    this.isBulk = false,
  });

  factory ProductSizeModel.fromMap(String id, Map<String, dynamic> data) {
    return ProductSizeModel(
      id: id,
      categoryId: data['category_id'] ?? '',
      label: data['label'] ?? '',
      weightInGrams: (data['weight_in_grams'] ?? 0).toDouble(),
      isBulk: data['is_bulk'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'label': label,
      'weight_in_grams': weightInGrams,
      'is_bulk': isBulk,
    };
  }
}
