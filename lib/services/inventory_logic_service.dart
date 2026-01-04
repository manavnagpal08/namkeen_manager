import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/warehouse_stock_model.dart';
import '../models/packing_unit_model.dart';

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
}
