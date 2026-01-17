import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/product_size_model.dart';
import '../../services/database_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  
  String? _categoryId;
  String? _defaultSizeId;
  List<String> _selectedSizeIds = [];
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(text: widget.product?.description ?? '');
    _categoryId = widget.product?.categoryId;
    _defaultSizeId = widget.product?.defaultSizeId;
    _selectedSizeIds = List.from(widget.product?.availableSizeIds ?? [], growable: true);
    
    // Initialize price controllers
    if (widget.product != null) {
      widget.product!.sizePrices.forEach((sizeId, price) {
        _priceControllers[sizeId] = TextEditingController(text: price.toString());
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'New Product' : 'Edit Product'),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name', hintText: 'e.g. Aloo Bhujia'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              
              // Category Dropdown
              StreamBuilder<List<CategoryModel>>(
                stream: db.getCategories(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (val) => setState(() {
                      _categoryId = val;
                      _defaultSizeId = null; // Reset size selection if category changes
                      _selectedSizeIds.clear();
                    }),
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
              ),
              
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 2,
              ),
              
              const SizedBox(height: 24),
              const SizedBox(height: 24),
              const Text('Packing Sizes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_categoryId == null)
                const Text('Select a Category first', style: TextStyle(color: Colors.grey))
              else
                StreamBuilder<List<ProductSizeModel>>(
                  stream: db.getSizes(),
                  builder: (context, snapshot) {
                    final sizes = snapshot.data ?? [];
                    if (sizes.isEmpty) {
                       return Column(
                         children: [
                           const Text('No sizes defined for this category.', style: TextStyle(color: Colors.red)),
                           TextButton.icon(
                             icon: const Icon(Icons.add),
                             label: const Text('Add "Standard" Size'),
                             onPressed: () async {
                               // Auto-create a standard size for this category
                               await db.addSize(ProductSizeModel(
                                 id: '', 
                                 label: 'Standard', 
                                 weightInGrams: 1000, 
                                 categoryId: _categoryId!,
                                 isBulk: false
                               ));
                             },
                           )
                         ],
                       );
                    }
                    
                    return Column(
                      children: sizes.map((size) {
                        final isSelected = _selectedSizeIds.contains(size.id);
                        return Column(
                           children: [
                             CheckboxListTile(
                               title: Text(size.label),
                               subtitle: Text('${size.weightInGrams}g ${size.isBulk ? '(Bulk)' : ''}'),
                               value: isSelected,
                               onChanged: (bool? selected) {
                                 setState(() {
                                   if (selected == true) {
                                     _selectedSizeIds.add(size.id);
                                     _defaultSizeId ??= size.id;
                                     _priceControllers.putIfAbsent(size.id, () => TextEditingController());
                                   } else {
                                     _selectedSizeIds.remove(size.id);
                                     if (_defaultSizeId == size.id) {
                                       _defaultSizeId = _selectedSizeIds.isNotEmpty ? _selectedSizeIds.first : null;
                                     }
                                   }
                                 });
                               },
                             ),
                             if (isSelected)
                               Padding(
                                 padding: const EdgeInsets.fromLTRB(48, 0, 16, 16),
                                 child: TextFormField(
                                   controller: _priceControllers.putIfAbsent(size.id, () => TextEditingController()),
                                   keyboardType: TextInputType.number,
                                   decoration: const InputDecoration(
                                     labelText: 'Selling Price (₹)',
                                     isDense: true,
                                     prefixText: '₹ ',
                                     border: OutlineInputBorder(),
                                   ),
                                 ),
                               ),
                           ],
                        );
                      }).toList(),
                    );
                  },
                ),

              const SizedBox(height: 12),
              if (_selectedSizeIds.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _defaultSizeId,
                  decoration: const InputDecoration(labelText: 'Default Size for Orders'),
                  items: _selectedSizeIds.map<DropdownMenuItem<String>>((id) {
                     return DropdownMenuItem<String>(value: id, child: Text('Size ID: ...${id.length > 4 ? id.substring(id.length - 4) : id}'));
                  }).toList(),
                   onChanged: (val) => setState(() => _defaultSizeId = val),
                 ),
                 
              const SizedBox(height: 12),
              const Text('Recipie / Bill of Materials (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('You can define the recipe for this product in the "Products & Recipes" screen after saving.', style: TextStyle(fontSize: 12, color: Colors.grey)),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  child: const Text('Save Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _selectedSizeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one size')));
      return;
    }

    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // Check for duplicate name (only for new products)
    if (widget.product == null) {
      final exists = await db.checkProductExists(_nameController.text.trim());
      if (exists) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Product with this name already exists!')));
        }
        return;
      }
    }
    
    // Collect prices
    final Map<String, double> prices = {};
    for (var sizeId in _selectedSizeIds) {
      if (_priceControllers.containsKey(sizeId)) {
        prices[sizeId] = double.tryParse(_priceControllers[sizeId]!.text) ?? 0.0;
      }
    }

    final product = ProductModel(
      id: widget.product?.id ?? '',
      name: _nameController.text.trim(),
      categoryId: _categoryId!,
      description: _descController.text.trim(),
      defaultSizeId: _defaultSizeId ?? _selectedSizeIds.first,
      availableSizeIds: _selectedSizeIds,
      sizePrices: prices,
    );

    try {
      if (widget.product == null) {
        await db.addProduct(product);
      } else {
        await db.updateProduct(product);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
