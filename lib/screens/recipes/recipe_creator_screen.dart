import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/product_model.dart';
import '../../models/raw_material_model.dart';
import '../../models/recipe_model.dart';
import '../../services/database_service.dart';

class RecipeCreatorScreen extends StatefulWidget {
  final ProductModel product;

  const RecipeCreatorScreen({super.key, required this.product});

  @override
  State<RecipeCreatorScreen> createState() => _RecipeCreatorScreenState();
}

class _RecipeCreatorScreenState extends State<RecipeCreatorScreen> {
  final _batchSizeController = TextEditingController(text: '100');
  List<RecipeIngredient> _ingredients = [];
  String? _existingRecipeId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingRecipe();
  }

  Future<void> _loadExistingRecipe() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final recipes = await db.getRecipes(productId: widget.product.id).first;
    
    if (recipes.isNotEmpty) {
      final recipe = recipes.first;
      setState(() {
        _existingRecipeId = recipe.id;
        _batchSizeController.text = recipe.batchBaseQuantityKg.toString();
        _ingredients = List.from(recipe.ingredients);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _addIngredient(String materialId) {
    if (_ingredients.any((i) => i.rawMaterialId == materialId)) return;
    setState(() {
      _ingredients.add(RecipeIngredient(rawMaterialId: materialId, quantityRequired: 0));
    });
  }

  void _updateQuantity(int index, String val) {
    final qty = double.tryParse(val) ?? 0;
    setState(() {
      final old = _ingredients[index];
      _ingredients[index] = RecipeIngredient(rawMaterialId: old.rawMaterialId, quantityRequired: qty);
    });
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe: ${widget.product.name}'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Text('Batch Base Size (kg): ', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _batchSizeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ingredients.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _ingredients.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Raw Material'),
                              onPressed: () => _showMaterialPicker(db),
                            ),
                          ),
                        );
                      }

                      final ing = _ingredients[index];
                      // Fetch material name requires stream or future. 
                      // For simplicity, we assume we can get it from a provider or just show ID for now?
                      // Better: Use a FutureBuilder to fetch name for display.
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: FutureBuilder<List<RawMaterialModel>>(
                                   // Inefficient to fetch all for name lookup, but ok for now
                                   future: db.getRawMaterials().first,
                                   builder: (context, snapshot) {
                                     final mat = snapshot.data?.firstWhere((m) => m.id == ing.rawMaterialId, orElse: () => RawMaterialModel(id: '', name: 'Unknown', unit: '', category: 'General', currentStock: 0, costPerUnit: 0, supplierName: 'Unknown', minimumThreshold: 0, storageLocation: 'Unknown', assignedDate: DateTime.now()));
                                     return Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(mat?.name ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.bold)),
                                         Text(mat?.unit ?? '', style: const TextStyle(color: Colors.grey)),
                                       ],
                                     );
                                   },
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: ing.quantityRequired.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                                  onChanged: (val) => _updateQuantity(index, val),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeIngredient(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _saveRecipe(db),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Save Recipe', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showMaterialPicker(DatabaseService db) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<List<RawMaterialModel>>(
          stream: db.getRawMaterials(),
          builder: (context, snapshot) {
            final materials = snapshot.data ?? [];
            return ListView.builder(
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final m = materials[index];
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text('${m.currentStock} ${m.unit} available'),
                  onTap: () {
                    _addIngredient(m.id);
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveRecipe(DatabaseService db) async {
    final batchSize = double.tryParse(_batchSizeController.text) ?? 100;
    
    final recipe = RecipeModel(
      id: _existingRecipeId ?? '',
      productId: widget.product.id,
      batchBaseQuantityKg: batchSize,
      ingredients: _ingredients,
    );

    if (_existingRecipeId == null) {
      await db.addRecipe(recipe);
    } else {
      await db.updateRecipe(recipe);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe Saved!')));
      Navigator.pop(context);
    }
  }
}
