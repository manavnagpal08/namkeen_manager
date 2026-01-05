import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/warehouse_stock_model.dart';
import '../models/packing_unit_model.dart';
import '../models/order_model.dart';
import '../models/recipe_model.dart';
import '../models/product_size_model.dart';
import '../models/raw_material_model.dart';

class InventoryLogicService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Completes a packaging assignment and moves stock to Warehouse
  Future<void> completePackagingTask({
    required String assignmentId,
    required double actualProducedPackets,
    required String batchId,
    required String batchCode, // Added param
    required String productId,
    required String sizeId,
    required String categoryId,
    required String employeeId,

    required PackingUnitModel? packingConfig,
    required String storageAreaId, // Added param
  }) async {
    final batch = _db.batch();
    
    // 1. Mark Assignment as Completed
    final assignmentRef = _db.collection('assignments').doc(assignmentId);
    batch.update(assignmentRef, {
      'status': 'Completed',
      'completed_units': actualProducedPackets,
      'completed_at': FieldValue.serverTimestamp(),
    });

    // 2. Calculate Hierarchy (Packets -> Boxes -> Cartons)
    // Default to 0 if no config
    int boxes = 0;
    int cartons = 0;
    
    if (packingConfig != null && packingConfig.packetsPerBox > 0) {
      boxes = (actualProducedPackets / packingConfig.packetsPerBox).floor();
      if (packingConfig.boxesPerMasterCarton > 0) {
        cartons = (boxes / packingConfig.boxesPerMasterCarton).floor();
      }
    }

    // 3. Create/Update Warehouse Stock Entry
    // We check if there's already an entry for this Batch+Product in Archive or just add new lot.
    // For traceability, usually we add a new "Lot" in stock logs, but dashboard sums it up.
    // We will add a new document for this "Inward" movement.
    final stockRef = _db.collection('warehouse_stock').doc();
    final newStockEntry = WarehouseStockModel(
      id: stockRef.id,
      productId: productId,
      categoryId: categoryId,
      sizeId: sizeId,
      batchId: batchId,
      batchCode: batchCode,
      warehouseUnitId: 'Main Warehouse', // Default for now
      storageAreaId: storageAreaId,
      inchargeEmployeeId: employeeId,
      quantityPackets: actualProducedPackets,
      quantityBoxes: boxes.toDouble(),
      quantityMasterCartons: cartons.toDouble(),
      updatedAt: DateTime.now(),
    );
    
    batch.set(stockRef, newStockEntry.toMap());

    // 4. Update Batch (Increment Packed Quantity)
    // We used 'packed_quantity_kg' in the model, but here it tracks whatever unit 'actualProducedPackets' is.
    // If mismatch (Kg vs Packets), conversion logic should be in UI.
    final batchRef = _db.collection('batches').doc(batchId);
    batch.update(batchRef, {
      'packed_quantity_kg': FieldValue.increment(actualProducedPackets),
    });
    

    await batch.commit();
  }

  /// Calculates Raw Material Requirements based on Pending Orders
  /// Returns a list of maps: { 'material': RawMaterialModel, 'required': double, 'deficit': double }
  Future<List<Map<String, dynamic>>> calculateRawMaterialRequirements() async {
    // 1. Fetch Pending Orders
    // We consider 'Created', 'Processing', 'Confirmed' as pending. Exclude 'Completed', 'Cancelled'.
    final orderSnap = await _db.collection('orders')
        .where('status', whereNotIn: ['Completed', 'Cancelled', 'Delivered'])
        .get();

    final orders = orderSnap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();

    // 2. Aggregate Demand by Product & Size
    // Map<ProductId, Map<SizeId, TotalTableQuantity>>
    // Actually we just need Total Weight per Product to apply Recipe
    final Map<String, double> productTargetWeightKg = {};

    // Cache Sizes to get weights
    final sizeSnap = await _db.collection('sizes').get();
    final sizeMap = { for (var d in sizeSnap.docs) d.id : ProductSizeModel.fromMap(d.id, d.data()) };

    for (var order in orders) {
      for (var item in order.items) {
        final size = sizeMap[item.sizeId];
        if (size == null) continue; // Skip if size deleted

        // Convert Packets to Kg
        // Quantity is usually in "Packets" (or Boxes if we supported that in OrderModel, assume packets for now)
        final weightKg = (item.quantity * size.weightInGrams) / 1000.0;
        
        productTargetWeightKg[item.productId] = (productTargetWeightKg[item.productId] ?? 0) + weightKg;
      }
    }

    // 3. Calculate Raw Material Needs
    final Map<String, double> materialNeeds = {}; // MaterialId -> QuantityKg

    // Cache Recipes
    final recipeSnap = await _db.collection('recipes').get();
    // Map<ProductId, RecipeModel> - Assuming 1 recipe per product for simplicity
    final recipeMap = { for (var d in recipeSnap.docs) d.data()['product_id'] as String : RecipeModel.fromMap(d.id, d.data()) };

    for (var entry in productTargetWeightKg.entries) {
      final pid = entry.key;
      final neededKg = entry.value;
      final recipe = recipeMap[pid];

      if (recipe == null) continue; // No recipe, can't calc

      // Ratio = Needed / Base
      if (recipe.batchBaseQuantityKg <= 0) continue;
      final ratio = neededKg / recipe.batchBaseQuantityKg;

      for (var ingredient in recipe.ingredients) {
        final requiredAmt = ingredient.quantityRequired * ratio;
        materialNeeds[ingredient.rawMaterialId] = (materialNeeds[ingredient.rawMaterialId] ?? 0) + requiredAmt;
      }
    }

    // 4. Compare with Stock
    final materialSnap = await _db.collection('raw_materials').get();
    final materials = materialSnap.docs.map((d) => RawMaterialModel.fromMap(d.id, d.data())).toList();

    final List<Map<String, dynamic>> results = [];

    for (var mat in materials) {
      final required = materialNeeds[mat.id] ?? 0.0;
      if (required > 0) {
        final deficit = (required - mat.currentStock) > 0 ? (required - mat.currentStock) : 0.0;
        results.add({
          'material': mat,
          'required': required,
          'deficit': deficit,
          'stock': mat.currentStock
        });
      }
    }
    
    // Sort by Deficit (descending)
    results.sort((a, b) => (b['deficit'] as double).compareTo(a['deficit'] as double));

    return results;
  }
}
