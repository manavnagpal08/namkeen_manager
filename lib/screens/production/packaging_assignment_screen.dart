import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/employee_model.dart';
import '../../models/batch_model.dart';
import '../../models/assignment_model.dart';
import '../../models/packing_unit_model.dart';
import '../../models/raw_material_model.dart';
import '../../services/database_service.dart';
import '../../services/stock_service.dart';
import '../../services/inventory_logic_service.dart';

class PackagingAssignmentScreen extends StatefulWidget {
  final BatchModel batch;
  const PackagingAssignmentScreen({super.key, required this.batch});

  @override
  State<PackagingAssignmentScreen> createState() => _PackagingAssignmentScreenState();
}

class _PackagingAssignmentScreenState extends State<PackagingAssignmentScreen> {
  String? _selectedEmployeeId;
  final _packetsCtrl = TextEditingController();
  
  PackingUnitModel? _config;
  int _boxes = 0;
  int _cartons = 0;

  // Track packaging materials (boxes, tape, packets)
  final List<Map<String, dynamic>> _selectedMaterials = [];

  @override
  void initState() {
    super.initState();
    _packetsCtrl.addListener(_updateCalculations);
    _loadConfig();
  }
  
  void _loadConfig() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       final db = Provider.of<DatabaseService>(context, listen: false);
       final config = await db.getPackingConfigForSize(widget.batch.sizeId);
       if (mounted) setState(() => _config = config);
    });
  }

  void _updateCalculations() {
    if (_config == null) return;
    int packets = int.tryParse(_packetsCtrl.text) ?? 0;
    
    int pktsPerBox = _config!.packetsPerBox;
    int boxesPerCarton = _config!.boxesPerMasterCarton;
    
    if (pktsPerBox > 0) {
      setState(() {
        _boxes = (packets / pktsPerBox).floor();
        if (boxesPerCarton > 0) {
          _cartons = (_boxes / boxesPerCarton).floor();
        }
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Packaging'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batch: ${widget.batch.batchCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_config == null)
                      const Text('⚠ No Packing Config found for this size. Defaulting to 1:1', style: TextStyle(color: Colors.orange))
                    else 
                      Text(
                        'Config: ${_config!.packetsPerBox} pkts/box | ${_config!.boxesPerMasterCarton} boxes/carton',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 24),
                    
                    StreamBuilder<List<EmployeeModel>>(
                      stream: db.getEmployees(),
                      builder: (context, snapshot) {
                        final employees = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Select Packaging Staff'),
                          value: _selectedEmployeeId,
                          items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.name))).toList(),
                          onChanged: (val) => setState(() => _selectedEmployeeId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _packetsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target Packets', suffixText: 'units'),
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text('Auto-Calculated Output:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                         _buildStatCard('Boxes', _boxes.toString(), Colors.blue),
                         _buildStatCard('Master Cartons', _cartons.toString(), Colors.green),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Packaging Materials:', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.secondary), onPressed: _addMaterialRow),
                      ],
                    ),
                    StreamBuilder<List<RawMaterialModel>>(
                      stream: db.getRawMaterials(),
                      builder: (context, snapshot) {
                        final allMaterials = snapshot.data ?? [];
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
                                              child: Text('${m.name} (${m.storageLocation})', style: const TextStyle(fontSize: 12)),
                                            )).toList(),
                                            onChanged: (val) => setState(() => row['material'] = val),
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
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _removeMaterialRow(index),
                                        ),
                                      ],
                                    ),
                                    if (selected != null)
                                      Text('Source: ${selected.storageLocation} | Supplier: ${selected.supplierName}', 
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () async {
                           if (_selectedEmployeeId == null || _packetsCtrl.text.isEmpty) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Employee and enter Target Packets')));
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
                                 'source': m.storageLocation,
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
                             type: 'Packaging',
                             status: 'Assigned',
                             assignedAt: DateTime.now(),
                             targetQuantity: double.tryParse(_packetsCtrl.text) ?? 0,
                             materialsUsed: mats,
                           );
                           
                           await db.assignTask(assignment);
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Packaging Task Assigned')));
                             _packetsCtrl.clear();
                             setState(() {
                               _selectedMaterials.clear();
                               _boxes = 0;
                               _cartons = 0;
                             });
                           }
                        },
                        child: const Text('Assign Packaging Task'),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const Text('Assignments for this Batch:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    StreamBuilder<List<AssignmentModel>>(
                      stream: db.getAssignments(batchId: widget.batch.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                           return const Center(child: Text('No active assignments.'));
                        }
                        final tasks = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true, // Use shrinkWrap inside column
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          itemBuilder: (ctx, index) {
                            final task = tasks[index];
                            final isCompleted = task.status == 'Completed';
                            return Card(
                              color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.white,
                              child: ListTile(
                                title: Text(task.type), 
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${task.targetQuantity} units • ${task.status}'),
                                    if (task.materialsUsed.isNotEmpty)
                                      Text('Materials: ${task.materialsUsed.map((m) => m['name']).join(', ')}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                trailing: isCompleted 
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.playlist_add_check, color: AppTheme.primary),
                                      tooltip: 'Mark Complete & Move to Warehouse',
                                      onPressed: () => _showCompletionDialog(context, task),
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionDialog(BuildContext context, AssignmentModel task) {
    final qtyCtrl = TextEditingController(text: task.targetQuantity.toString());
    final zoneCtrl = TextEditingController(text: 'Zone A');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Packaging'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirm produce quantity to move to Warehouse.'),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual Produced Packets', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
               controller: TextEditingController(text: 'Zone A'), // Default
               decoration: const InputDecoration(labelText: 'Storage Zone/Rack', border: OutlineInputBorder()),
               onChanged: (val) {
                 // We need a variable to hold this since we can't easily access controller inside the stateless dialog builder unless we define it outside
                 // But wait, the dialog builder is stateless.
                 // We should use a controller defined outside or a local one.
                 // Let's use a local variable captured in closure? No, rebuilding issues.
                 // Best: Use a new TextEditingController for this field defined in _showCompletionDialog
               },
            ),
            const SizedBox(height: 12),
            TextField(
               controller: zoneCtrl,
               decoration: const InputDecoration(labelText: 'Storage Zone/Rack', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _processCompletion(task, double.tryParse(qtyCtrl.text) ?? 0, zoneCtrl.text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _processCompletion(AssignmentModel task, double actualQty, String zone) async {
    try {
      final stockService = StockService(); 
      
      // We pass a copy of the task with the actual quantity entered 
      // so the service can calculate boxes correctly.
      final updTask = task.copyWith(completedUnits: actualQty);

      await stockService.processPackagingCompletion(updTask, _config);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Stock moved to Warehouse!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
