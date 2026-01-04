class RecipeModel {
  final String id;
  final String productId;
  final String name; // Added name
  final double batchBaseQuantityKg;
  final List<RecipeIngredient> ingredients;

  RecipeModel({
    required this.id,
    required this.productId,
    this.name = 'Standard Recipe', // Default
    required this.batchBaseQuantityKg,
    required this.ingredients,
  });

  factory RecipeModel.fromMap(String id, Map<String, dynamic> data) {
    return RecipeModel(
      id: id,
      productId: data['product_id'] ?? '',
      name: data['name'] ?? 'Recipe ${id.substring(0, 4)}',
      batchBaseQuantityKg: (data['batch_base_quantity_kg'] ?? 100).toDouble(),
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((x) => RecipeIngredient.fromMap(x))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'batch_base_quantity_kg': batchBaseQuantityKg,
      'ingredients': ingredients.map((x) => x.toMap()).toList(),
    };
  }
}

class RecipeIngredient {
  final String rawMaterialId;
  final double quantityRequired;

  RecipeIngredient({
    required this.rawMaterialId,
    required this.quantityRequired,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> data) {
    return RecipeIngredient(
      rawMaterialId: data['raw_material_id'] ?? '',
      quantityRequired: (data['quantity_required'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raw_material_id': rawMaterialId,
      'quantity_required': quantityRequired,
    };
  }
}
