import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/namkeen_theme.dart';
import '../../models/batch_model.dart';
import '../../models/product_model.dart';
import '../../models/product_size_model.dart';
import '../../models/employee_model.dart';
import '../../models/recipe_model.dart';
import '../../services/database_service.dart';
import '../../services/printing_service.dart';
import '../../services/stock_service.dart';
import 'manufacturing_assignment_screen.dart';
import 'packaging_assignment_screen.dart';

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Batches'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('Start Batch'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.secondary,
        onPressed: () => _showStartBatchDialog(context, db),
      ),
      body: StreamBuilder<List<BatchModel>>(
        stream: db.getBatches(activeOnly: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final batches = snapshot.data ?? [];
          if (batches.isEmpty) return const Center(child: Text('No batches logged yet.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              final isActive = batch.status != 'Completed';
              return Card(
                color: isActive ? Colors.white : Colors.grey.shade100,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.green : Colors.grey,
                    child: const Icon(Icons.sync, color: Colors.white),
                  ),
                  title: Text('${batch.batchCode} - ${batch.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Qty: ${batch.targetQuantityKg}kg • Started: ${DateFormat.Hm().format(batch.startTime)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.person_add, color: AppTheme.primary),
                                tooltip: 'Assign Task',
                                onSelected: (value) {
                                  if (value == 'man') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManufacturingAssignmentScreen(batch: batch)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => PackagingAssignmentScreen(batch: batch)));
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'man', child: Text('Assign Manufacturing')),
                                  const PopupMenuItem(value: 'pkg', child: Text('Assign Packaging')),
                                ],
                              ),
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.blueGrey),
                        tooltip: 'Print Report',
                        onPressed: () => _printReport(context, db, batch),
                      ),
                      if (batch.status == 'In Progress')
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green), 
                          tooltip: 'Complete Batch (Manual)',
                          onPressed: () => _completeBatch(context, db, batch),
                        )
                      else if (batch.status == 'Ready for Packing')
                         const Tooltip(message: 'Manufacturing Done. Assign Packing.', child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.inventory_2, color: Colors.orange))),
                      if (batch.status == 'Completed')
                        const Icon(Icons.check, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _printReport(BuildContext context, DatabaseService db, BatchModel batch) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Report...')));
    
    // Fetch related data
    final assignments = await db.getAssignments(batchId: batch.id).first;
    final employees = await db.getEmployees().first;
    
    // Print
    await PrintingService().printBatchReport(batch, assignments, employees);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _completeBatch(BuildContext context, DatabaseService db, BatchModel batch) {
    final quantityCtrl = TextEditingController(text: batch.targetQuantityKg.toString());
    final wastageCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text('Confirm actual production quantity:'),
             TextField(controller: quantityCtrl, decoration: const InputDecoration(labelText: 'Produced (kg)')),
             const SizedBox(height: 10),
             TextField(controller: wastageCtrl, decoration: const InputDecoration(labelText: 'Wastage (kg)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
               final produced = double.tryParse(quantityCtrl.text) ?? batch.targetQuantityKg;
               final wastage = double.tryParse(wastageCtrl.text) ?? 0;

               // Update Batch Status
               await db.updateBatch(batch.copyWith(
                 status: 'Completed',
                 endTime: DateTime.now(),
                 producedQuantityKg: produced,
                 wastageKg: wastage,
               ));

               // Trigger Stock Deduction (Auto)
               final stockService = StockService();
               // We deduct based on TOTAL material processed (Produced + Wastage)
               await stockService.deductRawMaterialsForBatch(batch, actualProducedKg: produced + wastage);

               if (context.mounted) {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch Completed & Stock Updated')));
               }
            },
            child: const Text('Finish Batch'),
          )
        ],
      ),
    );
  }

  void _showStartBatchDialog(BuildContext context, DatabaseService db) {
    String? selectedProductId;
    String? selectedProductName; // Track name for code generation
    String? selectedRecipeId;
    String? selectedSupervisorId;
    String? selectedSizeId;
    final qtyCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Start New Batch'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Creating Batch: ${selectedProductName != null ? "${selectedProductName!.substring(0, 3).toUpperCase()}-${DateFormat('ddMMM').format(DateTime.now())}" : "Select Product"}', 
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 10),
                  // Product Dropdown
                  StreamBuilder<List<ProductModel>>(
                    stream: db.getProducts(),
                    builder: (context, snapshot) {
                      final products = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: selectedProductId,
                        hint: const Text('Select Product'),
                        items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                        onChanged: (val) {
                          final name = products.firstWhere((p) => p.id == val).name;
                          setState(() {
                             selectedProductId = val;
                             selectedProductName = name;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Recipe Dropdown (Dynamic based on product)
                  if (selectedProductId != null)
                  StreamBuilder<List<RecipeModel>>(
                    stream: db.getRecipes(productId: selectedProductId),
                    builder: (context, snapshot) {
                      final recipes = snapshot.data ?? [];
                      if (recipes.isEmpty) return const Text('No recipes found for this product!', style: TextStyle(color: Colors.red));
                      
                      // Auto select first if only 1, or keep previous if valid
                      if (selectedRecipeId == null && recipes.isNotEmpty) {
                        // We can't setState inside build like this typically, but for simple dialog flow:
                         selectedRecipeId = recipes.first.id;
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedRecipeId,
                        hint: const Text('Select Recipe'),
                        items: recipes.map<DropdownMenuItem<String>>((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.name))).toList(),
                        onChanged: (val) => setState(() => selectedRecipeId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Size Dropdown
                  if (selectedProductId != null)
                  StreamBuilder<List<ProductModel>>(
                    stream: db.getProducts(),
                    builder: (context, psnap) {
                      final p = psnap.data?.firstWhere((element) => element.id == selectedProductId, orElse: () => ProductModel(id: '', name: '', categoryId: '', defaultSizeId: ''));
                      if (p == null || p.id.isEmpty) return const SizedBox.shrink();
                      
                      return StreamBuilder<List<ProductSizeModel>>(
                        stream: db.getSizes(), // We filter in memory for simplicity or use categoryId if getSizes supported it
                        builder: (context, sSnap) {
                          final sizes = (sSnap.data ?? []).where((s) => s.categoryId == p.categoryId).toList();
                          if (sizes.isEmpty) return const Text('No sizes defined for this category.', style: TextStyle(fontSize: 10, color: Colors.orange));

                          return DropdownButtonFormField<String>(
                            value: selectedSizeId,
                            hint: const Text('Select Packaging Size'),
                            items: sizes.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.label))).toList(),
                            onChanged: (val) => setState(() => selectedSizeId = val),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Supervisor Dropdown
                  StreamBuilder<List<EmployeeModel>>(
                    stream: db.getEmployees(),
                    builder: (context, snapshot) {
                      final employees = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: selectedSupervisorId,
                        hint: const Text('Select Supervisor'),
                        items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.name))).toList(),
                        onChanged: (val) => setState(() => selectedSupervisorId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target Quantity (kg)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                   if (selectedProductId == null || selectedSupervisorId == null) return;
                   
                   // Meaningful Batch Code: ALO-04JAN-1045
                   final pName = selectedProductName?.toUpperCase().replaceAll(' ', '').substring(0, 3) ?? 'BAT';
                   final date = DateFormat('ddMMM').format(DateTime.now()).toUpperCase();
                   final time = DateFormat('HHmm').format(DateTime.now());
                   final code = '$pName-$date-$time';
 
                   final batch = BatchModel(
                     id: '', // Firestore gen
                     batchCode: code,
                     productId: selectedProductId!,
                     recipeId: selectedRecipeId ?? '',
                     sizeId: selectedSizeId ?? 'Standard', 
                     targetQuantityKg: double.tryParse(qtyCtrl.text) ?? 100,
                     status: 'In Progress',
                     startTime: DateTime.now(),
                     supervisorId: selectedSupervisorId!,
                   );
                   await db.addBatch(batch);
                   if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Start'),
              ),
            ],
          );
        }
      ),
    );
  }
}
