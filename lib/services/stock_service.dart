import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/batch_model.dart';
import '../models/recipe_model.dart';
import '../models/packing_unit_model.dart';
import '../models/warehouse_stock_model.dart';
import '../models/assignment_model.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Deduct Raw Materials when Batch Starts
  Future<void> deductRawMaterialsForBatch(BatchModel batch, {double? actualProducedKg}) async {
    // Get recipe
    final recipeSnap = await _db.collection('recipes')
        .where('product_id', isEqualTo: batch.productId)
        .limit(1).get();
        
    if (recipeSnap.docs.isEmpty) return; // No recipe, no deduction

    final recipe = RecipeModel.fromMap(recipeSnap.docs.first.id, recipeSnap.docs.first.data());
    
    // Calculate Multiplier
    // Recipe is based on 'batchBaseQuantityKg' (e.g. 100kg)
    // We produced 'actualProducedKg' or planned 'targetQuantityKg'
    final productionQty = actualProducedKg ?? batch.targetQuantityKg;
    final baseQty = recipe.batchBaseQuantityKg > 0 ? recipe.batchBaseQuantityKg : 1.0;
    
    final multiplier = productionQty / baseQty; 
    
    // Transactional update
    await _db.runTransaction((transaction) async {
      for (var ingredient in recipe.ingredients) {
         final materialRef = _db.collection('raw_materials').doc(ingredient.rawMaterialId);
         final snapshot = await transaction.get(materialRef);
         if (snapshot.exists) {
           double currentStock = (snapshot.get('currentStock') ?? 0).toDouble();
           double deduction = ingredient.quantityRequired * multiplier;
           transaction.update(materialRef, {'currentStock': currentStock - deduction});
         }
      }
    });
  }

  // 2. Process Packaging Completion -> Add to Warehouse -> Deduct from Batch Output
  Future<void> processPackagingCompletion(AssignmentModel assignment, PackingUnitModel? config) async {
    if (assignment.type != 'Packaging' || assignment.status != 'Completed') return;

    // Get Batch
    final batchRef = _db.collection('batches').doc(assignment.batchId);
    final batchSnap = await batchRef.get();
    if (!batchSnap.exists) return;
    final batch = BatchModel.fromMap(batchSnap.id, batchSnap.data()!);

    // Calculate Units
    double packets = assignment.targetQuantity; // Assuming target was met
    double boxes = 0;
    double cartons = 0;

    if (config != null && config.packetsPerBox > 0) {
       boxes = (packets / config.packetsPerBox).floorToDouble();
       if (config.boxesPerMasterCarton > 0) {
         cartons = (boxes / config.boxesPerMasterCarton).floorToDouble();
       }
    }

    // Add to Warehouse Stock
    final warehouseRef = _db.collection('warehouse_stock').doc(); // New entry or merge?
    // For simplicity, adding new entry per batch-packaging run
    final stock = WarehouseStockModel(
      id: warehouseRef.id,
      productId: batch.productId,
      categoryId: config?.categoryId ?? '',
      sizeId: batch.sizeId,
      batchId: batch.id,
      quantityPackets: packets,
      quantityBoxes: boxes,
      quantityMasterCartons: cartons, 
      warehouseUnitId: 'Zone-1 (Auto)', 
      storageAreaId: 'Main Warehouse', 
      inchargeEmployeeId: assignment.employeeId, 
      updatedAt: DateTime.now()
    );

    // Update DB
    await _db.collection('warehouse_stock').add(stock.toMap());
    
    // Here we could also deduct from "Loose Batch Stock" if we were tracking that separately.
  }
}
