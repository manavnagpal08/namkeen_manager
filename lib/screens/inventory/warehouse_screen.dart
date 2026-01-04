import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../core/glass_container.dart';
import '../../models/warehouse_stock_model.dart';
import '../../models/product_model.dart';
import '../../models/batch_model.dart';
import '../../services/database_service.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse (Finished Goods)'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.mainGradient,
        ),
        child: Column(
          children: [
             // Search Bar
             Padding(
               padding: const EdgeInsets.all(16),
               child: TextField(
                 controller: _searchCtrl,
                 decoration: InputDecoration(
                   hintText: 'Search Product or Batch...',
                   prefixIcon: const Icon(Icons.search),
                   filled: true,
                   fillColor: Colors.white,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                   suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () {
                     _searchCtrl.clear();
                     setState(() => _searchQuery = '');
                   }),
                 ),
                 onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
               ),
             ),

             Expanded(
               child: StreamBuilder<List<ProductModel>>(
                stream: db.getProducts(),
                builder: (context, productSnap) {
                  final products = productSnap.data ?? [];
                  final productMap = {for (var p in products) p.id: p.name};

                  return StreamBuilder<List<BatchModel>>(
                    stream: db.getBatches(),
                    builder: (context, batchSnap) {
                      final batches = batchSnap.data ?? [];
                      final batchMap = {for (var b in batches) b.id: b.batchCode};

                      return StreamBuilder<List<WarehouseStockModel>>(
                        stream: db.getWarehouseStock(),
                        builder: (context, stockSnap) {
                          if (stockSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (stockSnap.hasError) return Center(child: Text('Error: ${stockSnap.error}'));

                          var stocks = stockSnap.data ?? [];

                          // Filter
                          if (_searchQuery.isNotEmpty) {
                            stocks = stocks.where((s) {
                              final pName = productMap[s.productId]?.toLowerCase() ?? '';
                              final bCode = s.batchCode.isNotEmpty ? s.batchCode.toLowerCase() : (batchMap[s.batchId]?.toLowerCase() ?? s.batchId.toLowerCase());
                              return pName.contains(_searchQuery) || bCode.contains(_searchQuery);
                            }).toList();
                          }

                          if (stocks.isEmpty) {
                            return const Center(child: Text('No matching stock found.'));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: stocks.length,
                            itemBuilder: (context, index) {
                              final stock = stocks[index];
                              final pName = productMap[stock.productId] ?? 'Unknown Product';
                              final bCode = stock.batchCode.isNotEmpty ? stock.batchCode : (batchMap[stock.batchId] ?? stock.batchId);
                              
                              // Aging Logic
                              final ageDays = DateTime.now().difference(stock.updatedAt).inDays;
                              final isOld = ageDays > 180;

                              return InkWell(
                                onTap: () {
                                  // Show Details Dialog
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('$pName Details'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Batch Code: $bCode', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text('Location: ${stock.warehouseUnitId}'),
                                          Text('Storage Area: ${stock.storageAreaId}'),
                                          Text('Last Updated: ${stock.updatedAt.toString().substring(0, 16)}'),
                                          if (isOld)
                                             Text('\nWarning: Stock is $ageDays days old.', style: const TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                                    ),
                                  );
                                },
                                child: GlassContainer(
                                  color: Colors.white,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  border: isOld ? Border.all(color: Colors.red, width: 2) : null,
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isOld ? Colors.red.withValues(alpha: 0.1) : Colors.teal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.inventory_2, color: isOld ? Colors.red : Colors.teal),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                const SizedBox(height: 4),
                                                Text('Batch: $bCode', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                                Text('Location: ${stock.warehouseUnitId}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                                if (isOld)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.warning, size: 14, color: Colors.red),
                                                        const SizedBox(width: 4),
                                                        Text('Old Stock ($ageDays days)', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStockItem('Packets', stock.quantityPackets),
                                          _buildStockItem('Boxes', stock.quantityBoxes),
                                          _buildStockItem('Cartons', stock.quantityMasterCartons),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () {},
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.local_shipping, size: 16),
                                          label: const Text('Dispatch / Move'),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    }
                  );
                }
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockItem(String label, double qty) {
    return Column(
      children: [
        Text(qty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
