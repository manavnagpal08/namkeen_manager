class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final String description;
  final String defaultSizeId;
  final List<String> availableSizeIds;
  final Map<String, double> sizePrices; // Map<SizeId, Price>

  ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description = '',
    required this.defaultSizeId,
    this.availableSizeIds = const [],
    this.sizePrices = const {},
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> data) {
    return ProductModel(
      id: id,
      name: data['name'] ?? '',
      categoryId: data['category_id'] ?? '',
      description: data['description'] ?? '',
      defaultSizeId: data['default_size_id'] ?? '',
      availableSizeIds: List<String>.from(data['available_size_ids'] ?? []),
      sizePrices: (data['size_prices'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category_id': categoryId,
      'description': description,
      'default_size_id': defaultSizeId,
      'available_size_ids': availableSizeIds,
      'size_prices': sizePrices,
    };
  }
}
