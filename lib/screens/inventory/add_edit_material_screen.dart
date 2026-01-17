import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/raw_material_model.dart';
import '../../services/database_service.dart';

class AddEditMaterialScreen extends StatefulWidget {
  final RawMaterialModel? material;

  const AddEditMaterialScreen({super.key, this.material});

  @override
  State<AddEditMaterialScreen> createState() => _AddEditMaterialScreenState();
}

class _AddEditMaterialScreenState extends State<AddEditMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _currentStockController;
  late TextEditingController _costController;
  late TextEditingController _supplierController;
  late TextEditingController _thresholdController;
  late TextEditingController _locationController;
  String _unit = 'kg';

  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material?.name ?? '');
    _currentStockController = TextEditingController(text: widget.material?.currentStock.toString() ?? '0');
    _costController = TextEditingController(text: widget.material?.costPerUnit.toString() ?? '0');
    _supplierController = TextEditingController(text: widget.material?.supplierName ?? ''); 
    _thresholdController = TextEditingController(text: widget.material?.minimumThreshold.toString() ?? '10');
    _locationController = TextEditingController(text: widget.material?.storageLocation ?? ''); 
    _unit = widget.material?.unit ?? 'kg';
    _expiryDate = widget.material?.expiryDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material == null ? 'Add Material' : 'Edit Material'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Basic Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Material Name', hintText: 'e.g. Besan'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: const [
                  DropdownMenuItem<String>(value: 'kg', child: Text('Kilograms (kg)')),
                  DropdownMenuItem<String>(value: 'litre', child: Text('Litres (L)')),
                  DropdownMenuItem<String>(value: 'pack', child: Text('Packets (pcs)')),
                  DropdownMenuItem<String>(value: 'tin', child: Text('Tin')),
                ],
                onChanged: (val) => setState(() => _unit = val!),
              ),
              
              const SizedBox(height: 24),
              const Text('Stock & Storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextFormField(
                        controller: _currentStockController,
                        keyboardType: TextInputType.number,
                        readOnly: widget.material != null,
                        decoration: InputDecoration(
                          labelText: 'Current Stock',
                          helperText: widget.material != null ? 'Use History to adjust' : null,
                          filled: widget.material != null,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Low Alert At', helperText: 'Min Threshold'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Storage Location', hintText: 'e.g. Room A, Rack 2'),
              ),

              const SizedBox(height: 24),
              const Text('Supplier Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Supplier Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cost Per Unit', prefixText: '₹ '),
              ),

              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _expiryDate = date);
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(text: _expiryDate != null ? _expiryDate!.toIso8601String().substring(0,10) : ''),
                    decoration: const InputDecoration(labelText: 'Expiry Date', suffixIcon: Icon(Icons.calendar_today)),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveMaterial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary, // Namkeen color
                  ),
                  child: const Text('Save Material', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;

    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final material = RawMaterialModel(
      id: widget.material?.id ?? '',
      name: _nameController.text.trim(),
      unit: _unit,
      category: 'General', // Default or add dropdown
      currentStock: double.tryParse(_currentStockController.text) ?? 0,
      costPerUnit: double.tryParse(_costController.text) ?? 0,
      minimumThreshold: double.tryParse(_thresholdController.text) ?? 0,
      supplierName: _supplierController.text.trim(),
      storageLocation: _locationController.text.trim(),
      assignedDate: widget.material?.assignedDate ?? DateTime.now(),
      expiryDate: _expiryDate,
    );

    try {
      if (widget.material == null) {
        await db.addRawMaterial(material);
      } else {
        await db.updateRawMaterial(material);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
