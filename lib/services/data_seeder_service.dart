import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/raw_material_model.dart';
import '../models/category_model.dart';
import '../models/product_size_model.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';

class DataSeederService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedData() async {
    debugPrint('Seeding Categories...');
    final batch = _db.batch();

    // 1. Raw Materials
    final materialIds = <String, String>{};
    final materials = [
      {'name': 'Besan (Chickpea Flour)', 'unit': 'kg', 'cost': 75.0, 'stock': 500.0, 'min': 50.0},
      {'name': 'Refined Oil', 'unit': 'L', 'cost': 110.0, 'stock': 200.0, 'min': 40.0},
      {'name': 'Red Chilli Powder', 'unit': 'kg', 'cost': 250.0, 'stock': 20.0, 'min': 5.0},
      {'name': 'Salt', 'unit': 'kg', 'cost': 20.0, 'stock': 100.0, 'min': 10.0},
      {'name': 'Turmeric (Haldi)', 'unit': 'kg', 'cost': 180.0, 'stock': 15.0, 'min': 2.0},
      {'name': 'Moong Dal', 'unit': 'kg', 'cost': 95.0, 'stock': 300.0, 'min': 30.0},
    ];

    for (var m in materials) {
      final docRef = _db.collection('raw_materials').doc();
      materialIds[m['name'] as String] = docRef.id;
      batch.set(docRef, RawMaterialModel(
        id: docRef.id,
        name: m['name'] as String,
        unit: m['unit'] as String,
        currentStock: m['stock'] as double,
        costPerUnit: m['cost'] as double,
        supplierName: 'Seed Supplier',
        minimumThreshold: m['min'] as double,
        category: 'General',
        storageLocation: 'Warehouse A',
        assignedDate: DateTime.now(),
      ).toMap());
    }

    // 2. Categories
    final catIds = <String, String>{};
    final categories = ['Namkeen', 'Sweets', 'Fryums'];
    
    for (var c in categories) {
      final docRef = _db.collection('categories').doc();
      catIds[c] = docRef.id;
      batch.set(docRef, CategoryModel(
        id: docRef.id,
        name: c,
        type: 'Standard',
        createdAt: DateTime.now(),
      ).toMap());
    }

    // 3. Sizes
    final sizeIds = <String, String>{};
    final namkeenSizes = [
      {'label': '200g Pouch', 'g': 200.0, 'bulk': false},
      {'label': '400g Pouch', 'g': 400.0, 'bulk': false},
      {'label': '1kg Box', 'g': 1000.0, 'bulk': false},
      {'label': '5kg Sack', 'g': 5000.0, 'bulk': true},
    ];

    if (catIds['Namkeen'] != null) {
      for (var s in namkeenSizes) {
        final docRef = _db.collection('product_sizes').doc();
        sizeIds[s['label'] as String] = docRef.id;
        batch.set(docRef, ProductSizeModel(
          id: docRef.id,
          categoryId: catIds['Namkeen']!,
          label: s['label'] as String,
          weightInGrams: s['g'] as double,
          isBulk: s['bulk'] as bool,
        ).toMap());
      }
    }

    // 4. Products
    final prodIds = <String, String>{};
    if (catIds['Namkeen'] != null && sizeIds.isNotEmpty) {
      final bhujiaRef = _db.collection('products').doc();
      prodIds['Aloo Bhujia'] = bhujiaRef.id;
      
      batch.set(bhujiaRef, ProductModel(
        id: bhujiaRef.id,
        name: 'Aloo Bhujia',
        categoryId: catIds['Namkeen']!,
        description: 'Spicy potato noodles using Besan & Oil',
        defaultSizeId: sizeIds['400g Pouch'] ?? '',
        availableSizeIds: sizeIds.values.toList(),
      ).toMap());

      final moongRef = _db.collection('products').doc();
      prodIds['Moong Dal'] = moongRef.id;
       batch.set(moongRef, ProductModel(
        id: moongRef.id,
        name: 'Moong Dal',
        categoryId: catIds['Namkeen']!,
        description: 'Fried salted moong dal',
        defaultSizeId: sizeIds['200g Pouch'] ?? '',
        availableSizeIds: sizeIds.values.toList(),
      ).toMap());
    }

    // 5. Recipes
    // Aloo Bhujia Recipe (100kg batch)
    if (prodIds['Aloo Bhujia'] != null && materialIds['Besan (Chickpea Flour)'] != null) {
      final recipeRef = _db.collection('recipes').doc();
      batch.set(recipeRef, RecipeModel(
        id: recipeRef.id,
        productId: prodIds['Aloo Bhujia']!,
        batchBaseQuantityKg: 100.0,
        ingredients: [
          RecipeIngredient(rawMaterialId: materialIds['Besan (Chickpea Flour)']!, quantityRequired: 60.0),
          RecipeIngredient(rawMaterialId: materialIds['Refined Oil']!, quantityRequired: 20.0),
          RecipeIngredient(rawMaterialId: materialIds['Red Chilli Powder']!, quantityRequired: 2.0),
          RecipeIngredient(rawMaterialId: materialIds['Salt']!, quantityRequired: 1.5),
        ],
      ).toMap());
    }
    
    // Moong Dal Recipe (100kg batch)
    if (prodIds['Moong Dal'] != null && materialIds['Moong Dal'] != null) {
      final recipeRef = _db.collection('recipes').doc();
      batch.set(recipeRef, RecipeModel(
        id: recipeRef.id,
        productId: prodIds['Moong Dal']!,
        batchBaseQuantityKg: 100.0,
        ingredients: [
          RecipeIngredient(rawMaterialId: materialIds['Moong Dal']!, quantityRequired: 85.0),
          RecipeIngredient(rawMaterialId: materialIds['Refined Oil']!, quantityRequired: 12.0),
          RecipeIngredient(rawMaterialId: materialIds['Salt']!, quantityRequired: 1.0),
        ],
      ).toMap());
    }

    await batch.commit();
    debugPrint('✅ Data Seeding Completed!');
  }
}
