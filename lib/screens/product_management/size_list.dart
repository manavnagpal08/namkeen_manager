import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/product_size_model.dart';
import '../../models/category_model.dart';
import '../../services/database_service.dart';

class SizeList extends StatefulWidget {
  const SizeList({super.key});

  @override
  State<SizeList> createState() => _SizeListState();
}

class _SizeListState extends State<SizeList> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<DatabaseService>(context);

    // Prepare Category Stream for Dropdown filter
    final categoryStream = database.getCategories();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.secondary,
        onPressed: () => _showAddEditDialog(context, database),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: StreamBuilder<List<CategoryModel>>(
              stream: categoryStream,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];
                return DropdownButtonFormField<String?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Category',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                    ...categories.map<DropdownMenuItem<String?>>((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                );
              },
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<ProductSizeModel>>(
              stream: database.getSizes(categoryId: _selectedCategoryId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sizes = snapshot.data ?? [];
                
                if (sizes.isEmpty) {
                  return const Center(child: Text('No sizes found. Add one!'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sizes.length,
                  itemBuilder: (context, index) {
                    final size = sizes[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          size.isBulk ? Icons.inventory_2 : Icons.shopping_bag,
                          color: size.isBulk ? Colors.orange : Colors.blue,
                        ),
                        title: Text(size.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${size.weightInGrams}g ${size.isBulk ? '(Bulk)' : ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => database.deleteSize(size.id),
                        ),
                        onTap: () => _showAddEditDialog(context, database, size: size),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, DatabaseService db, {ProductSizeModel? size}) {
    final labelController = TextEditingController(text: size?.label ?? '');
    final weightController = TextEditingController(text: size?.weightInGrams.toString() ?? '');
    String? categoryId = size?.categoryId ?? _selectedCategoryId; // Default to filter selection
    bool isBulk = size?.isBulk ?? false;
    final isEditing = size != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Size' : 'Add Size'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Dropdown
                    StreamBuilder<List<CategoryModel>>(
                      stream: db.getCategories(),
                      builder: (context, snapshot) {
                         // If we are adding and haven't selected a category, default to first if avail
                        final categories = snapshot.data ?? [];
                        if (categoryId == null && categories.isNotEmpty) {
                           categoryId = categories.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          value: categoryId,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (val) => setStateDialog(() => categoryId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: 'Label (e.g. 200g)', hintText: 'Display Name'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Weight (grams)', hintText: '200'),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Is Bulk Production Size?'),
                      subtitle: const Text('Check if this is for manufacturing batches (e.g. 100kg)'),
                      value: isBulk,
                      onChanged: (val) => setStateDialog(() => isBulk = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (labelController.text.trim().isEmpty || categoryId == null) return;
                    
                    final newSize = ProductSizeModel(
                      id: size?.id ?? '',
                      categoryId: categoryId!,
                      label: labelController.text.trim(),
                      weightInGrams: double.tryParse(weightController.text) ?? 0,
                      isBulk: isBulk,
                    );

                    if (isEditing) {
                      await db.updateSize(newSize);
                    } else {
                      await db.addSize(newSize);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
