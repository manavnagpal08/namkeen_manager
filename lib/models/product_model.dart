class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final String description;
  final String defaultSizeId;
  final List<String> availableSizeIds;

  ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description = '',
    required this.defaultSizeId,
    this.availableSizeIds = const [],
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> data) {
    return ProductModel(
      id: id,
      name: data['name'] ?? '',
      categoryId: data['category_id'] ?? '',
      description: data['description'] ?? '',
      defaultSizeId: data['default_size_id'] ?? '',
      availableSizeIds: List<String>.from(data['available_size_ids'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category_id': categoryId,
      'description': description,
      'default_size_id': defaultSizeId,
      'available_size_ids': availableSizeIds,
    };
  }
}
