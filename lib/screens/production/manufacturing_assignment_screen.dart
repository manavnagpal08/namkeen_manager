import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/employee_model.dart';
import '../../models/batch_model.dart';
import '../../models/assignment_model.dart';
import '../../models/raw_material_model.dart';
import '../../services/database_service.dart';

class ManufacturingAssignmentScreen extends StatefulWidget {
  final BatchModel batch;
  const ManufacturingAssignmentScreen({super.key, required this.batch});

  @override
  State<ManufacturingAssignmentScreen> createState() => _ManufacturingAssignmentScreenState();
}

class _ManufacturingAssignmentScreenState extends State<ManufacturingAssignmentScreen> {
  String? _selectedEmployeeId;
  final _targetCtrl = TextEditingController();
  
  // List to track selected materials: {materialId, quantity}
  final List<Map<String, dynamic>> _selectedMaterials = [];

  bool _recipeLoaded = false;

  void _addMaterialRow() {
    setState(() {
      _selectedMaterials.add({'material': null, 'qty': TextEditingController()});
    });
  }

  void _removeMaterialRow(int index) {
    setState(() {
      _selectedMaterials.removeAt(index);
    });
  }
  
  Future<void> _loadRecipe(DatabaseService db, List<RawMaterialModel> allMaterials) async {
    // Avoid double loading
    Future.microtask(() async {
       if (!mounted) return;
        _recipeLoaded = true; 
        if (widget.batch.recipeId.isEmpty) return;

        try {
           final recipes = await db.getRecipes(productId: widget.batch.productId).first;
           // If batch has a specific recipeId, us it. Otherwise default to first? 
           // Batch ALWAYS has recipeId if created via new dialog.
           final recipe = recipes.firstWhere((r) => r.id == widget.batch.recipeId, orElse: () => recipes.first);
           
           final target = double.tryParse(_targetCtrl.text) ?? widget.batch.targetQuantityKg;
           if (_targetCtrl.text.isEmpty) _targetCtrl.text = target.toString();
           
           final ratio = target / (recipe.batchBaseQuantityKg == 0 ? 1 : recipe.batchBaseQuantityKg);
           
           setState(() {
              _selectedMaterials.clear(); // Clear manual if any
              for (var ing in recipe.ingredients) {
                  // Find matching raw material
                  try {
                    final mat = allMaterials.firstWhere((m) => m.id == ing.rawMaterialId);
                    _selectedMaterials.add({
                      'material': mat,
                      'qty': TextEditingController(text: (ing.quantityRequired * ratio).toStringAsFixed(2))
                    });
                  } catch (e) {
                    // Material not found in current list (maybe deleted?)
                  }
              }
           });
        } catch (e) {
           debugPrint('Error auto-loading recipe: $e');
        }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Manufacturing'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch: ${widget.batch.batchCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            StreamBuilder<List<EmployeeModel>>(
              stream: db.getEmployees(),
              builder: (context, snapshot) {
                final employees = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Chef / Worker'),
                  value: _selectedEmployeeId,
                  items: employees.where((e) => e.role != 'Driver').map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                  onChanged: (val) => setState(() => _selectedEmployeeId = val),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Quantity (kg)', suffixText: 'kg'),
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Raw Materials to Use:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.secondary), onPressed: _addMaterialRow),
              ],
            ),
            const SizedBox(height: 8),

            StreamBuilder<List<RawMaterialModel>>(
              stream: db.getRawMaterials(),
              builder: (context, snapshot) {
                final allMaterials = snapshot.data ?? [];
                
                // Auto-load recipe if available and not yet loaded
                if (!_recipeLoaded && allMaterials.isNotEmpty) {
                  _loadRecipe(db, allMaterials);
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedMaterials.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _selectedMaterials[index];
                    RawMaterialModel? selected = row['material'];
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<RawMaterialModel>(
                                    decoration: const InputDecoration(labelText: 'Material', isDense: true),
                                    value: selected,
                                    items: allMaterials.map<DropdownMenuItem<RawMaterialModel>>((m) => DropdownMenuItem<RawMaterialModel>(
                                      value: m,
                                      child: Text('${m.name} (${m.storageLocation})', style: const TextStyle(fontSize: 13)),
                                    )).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        row['material'] = val;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: row['qty'],
                                    decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _removeMaterialRow(index),
                                ),
                              ],
                            ),
                            if (selected != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Source: ${selected.storageLocation} | Supplier: ${selected.supplierName}', 
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () async {
                  if (_selectedEmployeeId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an employee')));
                    return;
                  }
                  
                  // Prepare materials list
                  List<Map<String, dynamic>> mats = [];
                  for (var row in _selectedMaterials) {
                    RawMaterialModel? m = row['material'];
                    if (m != null) {
                      mats.add({
                        'name': m.name,
                        'materialId': m.id,
                        'source': m.storageLocation, // This is explicitly what the user asked for
                        'supplier': m.supplierName,
                        'quantity': row['qty'].text,
                      });
                    }
                  }

                  final assignment = AssignmentModel(
                    id: '',
                    batchId: widget.batch.id,
                    batchCode: widget.batch.batchCode,
                    employeeId: _selectedEmployeeId!,
                    type: 'Manufacturing',
                    status: 'Assigned',
                    assignedAt: DateTime.now(),
                    targetQuantity: double.tryParse(_targetCtrl.text) ?? 0,
                    materialsUsed: mats,
                  );
                  
                  await db.assignTask(assignment);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Assigned with Material Source')));
                    Navigator.pop(context);
                  }
                },
                child: const Text('Assign Task'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
