import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/batch_model.dart';
import '../models/recipe_model.dart';
import '../models/packing_unit_model.dart';
import '../models/warehouse_stock_model.dart';
import '../models/assignment_model.dart';
import '../models/raw_material_model.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Deduct Raw Materials when Batch Starts
  // 1. Deduct Raw Materials when Batch Starts (or Completes)
  Future<void> deductRawMaterialsForBatch(BatchModel batch, {double? actualProducedKg, List<Map<String, dynamic>>? usedMaterials}) async {
    debugPrint('Starting deduction for batch: ${batch.batchCode}');
    
    // Strategy: If specific materials were assigned (Manual or Recipe-based at assignment time), use those.
    // Otherwise, fetch the current recipe as a fallback.
    
    if (usedMaterials != null && usedMaterials.isNotEmpty) {
      debugPrint('Using specific materials from assignment task.');
      await _db.runTransaction((transaction) async {
        for (var item in usedMaterials) {
           final String? matId = item['materialId'];
           if (matId == null) continue;
           
           // Handle quantity (might be String or num)
           final double deduction = double.tryParse(item['quantity'].toString()) ?? 0;
           if (deduction <= 0) continue;

           final materialRef = _db.collection('raw_materials').doc(matId);
           final snapshot = await transaction.get(materialRef);
           
           if (snapshot.exists) {
             double currentStock = (snapshot.get('currentStock') ?? 0).toDouble();
             debugPrint('Deducting $deduction from $matId (Current: $currentStock)');
             
             transaction.update(materialRef, {'currentStock': currentStock - deduction});
             
             // Add history log
             final historyRef = _db.collection('raw_materials').doc(matId).collection('history').doc();
             transaction.set(historyRef, {
               'date': DateTime.now(),
               'changeAmount': -deduction,
               'reason': 'Production Batch ${batch.batchCode}',
               'newStock': currentStock - deduction,
               'isAddition': false,
             });
           } else {
              debugPrint('Material $matId not found in DB');
           }
        }
      });
      return; // Done
    }

    // --- Fallback to Recipe if no materials provided ---
    debugPrint('No assigned materials found. Falling back to Recipe lookup.');
    
    final recipeSnap = await _db.collection('recipes')
        .where('product_id', isEqualTo: batch.productId)
        .limit(1).get();
        
    if (recipeSnap.docs.isEmpty) {
      debugPrint('CRITICAL: No recipe found for product ${batch.productId}');
      throw Exception('Recipe not found for product ID: ${batch.productId}. Cannot deduct stock.');
    }

    final recipe = RecipeModel.fromMap(recipeSnap.docs.first.id, recipeSnap.docs.first.data());
    debugPrint('Found Recipe: ${recipe.name}');
    
    // Calculate Multiplier
    final productionQty = actualProducedKg ?? batch.targetQuantityKg;
    final baseQty = recipe.batchBaseQuantityKg > 0 ? recipe.batchBaseQuantityKg : 1.0;
    final multiplier = productionQty / baseQty; 
    
    debugPrint('Production Qty: $productionQty, Base Qty: $baseQty, Multiplier: $multiplier');
    
    await _db.runTransaction((transaction) async {
      for (var ingredient in recipe.ingredients) {
         final materialRef = _db.collection('raw_materials').doc(ingredient.rawMaterialId);
         final snapshot = await transaction.get(materialRef);
         if (snapshot.exists) {
           double currentStock = (snapshot.get('currentStock') ?? 0).toDouble();
           double deduction = ingredient.quantityRequired * multiplier;
           debugPrint('Deducting $deduction from ${ingredient.rawMaterialId} (Current: $currentStock)');
           
           transaction.update(materialRef, {'currentStock': currentStock - deduction});
           
           final historyRef = _db.collection('raw_materials').doc(ingredient.rawMaterialId).collection('history').doc();
           transaction.set(historyRef, {
             'date': DateTime.now(),
             'changeAmount': -deduction,
             'reason': 'Production Batch ${batch.batchCode} (Auto-Recipe)',
             'newStock': currentStock - deduction,
             'isAddition': false,
           });
         }
      }
    });
  }

  // 2. Process Packaging Completion -> Add to Warehouse -> Deduct from Batch Output
  Future<void> processPackagingCompletion(AssignmentModel assignment, PackingUnitModel? config) async {
    if (assignment.type != 'Packaging') return;

    // Get Batch
    final batchRef = _db.collection('batches').doc(assignment.batchId);
    final batchSnap = await batchRef.get();
    if (!batchSnap.exists) return;
    final batch = BatchModel.fromMap(batchSnap.id, batchSnap.data()!);

    // Refine Config if null (Fallback to Category)
    PackingUnitModel? finalConfig = config;
    if (finalConfig == null) {
      final productSnap = await _db.collection('products').doc(batch.productId).get();
      if (productSnap.exists) {
        final categoryId = productSnap.data()?['category_id'] ?? '';
        finalConfig = await _db.collection('packing_units')
            .where('sizeId', isEqualTo: batch.sizeId)
            .limit(1).get().then((q) => q.docs.isNotEmpty ? PackingUnitModel.fromMap(q.docs.first.data(), q.docs.first.id) : null);
        
        if (finalConfig == null && categoryId.isNotEmpty) {
           finalConfig = await _db.collection('packing_units')
              .where('categoryId', isEqualTo: categoryId)
              .limit(1).get().then((q) => q.docs.isNotEmpty ? PackingUnitModel.fromMap(q.docs.first.data(), q.docs.first.id) : null);
        }
      }
    }

    // Calculate Units
    double packets = (assignment.completedUnits > 0) ? assignment.completedUnits : assignment.targetQuantity;
    double boxes = 0;
    double cartons = 0;

    if (finalConfig != null && finalConfig.packetsPerBox > 0) {
       boxes = (packets / finalConfig.packetsPerBox).floorToDouble();
       if (finalConfig.boxesPerMasterCarton > 0) {
         cartons = (boxes / finalConfig.boxesPerMasterCarton).floorToDouble();
       }
    }

    // Add to Warehouse Stock
    final warehouseRef = _db.collection('warehouse_stock').doc(); 
    final stock = WarehouseStockModel(
      id: warehouseRef.id,
      productId: batch.productId,
      categoryId: finalConfig?.categoryId ?? '',
      sizeId: batch.sizeId,
      batchId: batch.id,
      batchCode: batch.batchCode,
      quantityPackets: packets,
      quantityBoxes: boxes,
      quantityMasterCartons: cartons, 
      warehouseUnitId: 'Zone-1 (Auto)', 
      storageAreaId: 'Main Warehouse', 
      inchargeEmployeeId: assignment.employeeId, 
      updatedAt: DateTime.now()
    );

    // Update DB
    final batchDb = _db.batch();
    
    // 1. Mark Assignment Completed
    batchDb.update(_db.collection('assignments').doc(assignment.id), {
      'status': 'Completed',
      'completed_units': packets,
      'completed_at': FieldValue.serverTimestamp(),
    });

    // 2. Add Warehouse Stock
    batchDb.set(warehouseRef, stock.toMap());

    // 3. Update Batch (Increment Packed Quantity)
    batchDb.update(batchRef, {
      'packed_quantity_kg': FieldValue.increment(packets),
    });

    await batchDb.commit();

    // 4. Deduct Packaging Materials (Sequential call as it has its own transaction/logic)
    if (assignment.materialsUsed.isNotEmpty) {
      await deductRawMaterialsForBatch(batch, usedMaterials: assignment.materialsUsed);
    }
  }

  // 3. Forecast Stock Days Remaining
  Future<List<Map<String, dynamic>>> getStockForecast() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // A. Fetch Data
    final materialsSnap = await _db.collection('raw_materials').get();
    final materials = materialsSnap.docs.map((d) => RawMaterialModel.fromMap(d.id, d.data())).toList();

    // Fetch assignments is tricky without composite index on Date.
    // We'll fetch all assignments and filter in memory (assuming not millions yet) or use batch approach.
    // Better: Fetch 'batches' completed in last 30 days.
    final batchesSnap = await _db.collection('batches')
        .where('status', isEqualTo: 'Ready for Packing') // or Packaged
        // .where('startTime', isGreaterThan: thirtyDaysAgo) // Needs index
        .get();
    
    // In-memory filter for date if index fails
    final validBatches = batchesSnap.docs
        .map((d) => BatchModel.fromMap(d.id, d.data()))
        .where((b) => b.startTime.isAfter(thirtyDaysAgo))
        .toList();

    final recipesSnap = await _db.collection('recipes').get();
    final recipes = recipesSnap.docs.map((d) => RecipeModel.fromMap(d.id, d.data())).toList();

    // B. Calculate Usage
    final Map<String, double> usageMap = {}; // MaterialId -> Total Used

    for (var batch in validBatches) {
      final recipe = recipes.firstWhere((r) => r.productId == batch.productId, orElse: () => RecipeModel(id: '', productId: '', ingredients: [], batchBaseQuantityKg: 1));
      if (recipe.id.isEmpty) continue;

      // Approx usage based on target or actual?
      // We'll use targetQuantityKg for simplicity of forecasting
      final multiplier = batch.targetQuantityKg / (recipe.batchBaseQuantityKg > 0 ? recipe.batchBaseQuantityKg : 1);

      for (var ing in recipe.ingredients) {
        usageMap[ing.rawMaterialId] = (usageMap[ing.rawMaterialId] ?? 0) + (ing.quantityRequired * multiplier);
      }
    }

    // C. Daily Rate & Days Left
    final List<Map<String, dynamic>> forecast = [];

    for (var mat in materials) {
      final totalUsed30Days = usageMap[mat.id] ?? 0;
      final dailyRate = totalUsed30Days / 30;
      
      int daysLeft = 999;
      if (dailyRate > 0) {
        daysLeft = (mat.currentStock / dailyRate).floor();
      }

      forecast.add({
        'id': mat.id,
        'name': mat.name,
        'currentStock': mat.currentStock,
        'dailyUsage': dailyRate,
        'daysLeft': daysLeft,
        'status': daysLeft < 3 ? 'Critical' : (daysLeft < 7 ? 'Low' : 'Good'),
      });
    }

    // Sort by Days Left (Ascending)
    forecast.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));
    return forecast;
  }
}

