import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/category_model.dart';
import '../../models/product_size_model.dart';
import '../../models/packing_unit_model.dart';
import '../../services/database_service.dart';

class ManagePackingScreen extends StatefulWidget {
  const ManagePackingScreen({super.key});

  @override
  State<ManagePackingScreen> createState() => _ManagePackingScreenState();
}

class _ManagePackingScreenState extends State<ManagePackingScreen> {
  String? _selectedCategory;
  String? _selectedSize;

  final _packetsCtrl = TextEditingController(text: '1');
  final _boxesCtrl = TextEditingController(text: '1');
  final _cartonCtrl = TextEditingController(text: '1');
  String? _existingConfigId;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packing Configuration'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Define Hierarchy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Set how many packets go into a box, master carton, etc. for a specific size.'),
            const SizedBox(height: 24),

            // 1. Select Category
            StreamBuilder<List<CategoryModel>>(
              stream: db.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Select Category'),
                  items: snapshot.data!.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSize = null;
                      _resetForm();
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Select Size (Filtered by Category)
            if (_selectedCategory != null)
              StreamBuilder<List<ProductSizeModel>>(
                stream: db.getSizes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  if (snapshot.data!.isEmpty) return const Text('No sizes found for this category.');
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedSize,
                    decoration: const InputDecoration(labelText: 'Select Size / Weight'),
                    items: snapshot.data!.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.label))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedSize = val);
                      _loadExistingConfig(db);
                    },
                  );
                },
              ),

            if (_selectedSize != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text('1 Box contains:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _packetsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Packets', suffixText: 'pkts'))),
                  const SizedBox(width: 16),
                  const Text('=', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('1 Box (Unit)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),

              const SizedBox(height: 24),
              const Text('1 Master Carton contains:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _boxesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Boxes', suffixText: 'boxes'))),
                  const SizedBox(width: 16),
                  const Text('=', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('1 Master Carton', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),

              const SizedBox(height: 24),
              const Text('1 Warehouse Unit contains:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _cartonCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Master Cartons', suffixText: 'cartons'))),
                  const SizedBox(width: 16),
                  const Text('=', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('1 Storage Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _saveConfig(db),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Configuration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadExistingConfig(DatabaseService db) async {
    if (_selectedSize == null) return;
    final config = await db.getPackingConfigForSize(_selectedSize!);
    if (config != null) {
      setState(() {
        _existingConfigId = config.id;
        _packetsCtrl.text = config.packetsPerBox.toString();
        _boxesCtrl.text = config.boxesPerMasterCarton.toString();
        _cartonCtrl.text = config.masterCartonsPerWarehouseUnit.toString();
      });
    } else {
      _resetForm();
    }
  }

  void _resetForm() {
    setState(() {
      _existingConfigId = null;
      _packetsCtrl.text = '1';
      _boxesCtrl.text = '1';
      _cartonCtrl.text = '1';
    });
  }

  Future<void> _saveConfig(DatabaseService db) async {
    if (_selectedSize == null || _selectedCategory == null) return;

    final config = PackingUnitModel(
      id: _existingConfigId ?? '',
      categoryId: _selectedCategory!,
      sizeId: _selectedSize!,
      packetsPerBox: int.tryParse(_packetsCtrl.text) ?? 1,
      boxesPerMasterCarton: int.tryParse(_boxesCtrl.text) ?? 1,
      masterCartonsPerWarehouseUnit: int.tryParse(_cartonCtrl.text) ?? 1,
      updatedAt: DateTime.now(),
    );

    await db.savePackingConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration Saved!')));
    }
  }
}
