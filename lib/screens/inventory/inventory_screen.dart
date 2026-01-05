import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/raw_material_model.dart';
import '../../services/database_service.dart';
import 'add_edit_material_screen.dart';
import 'raw_material_history_screen.dart';
import '../../services/stock_service.dart';
import 'forecast_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<DatabaseService>(context);

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text('Raw Material Inventory'),
        backgroundColor: AppTheme.primary.withValues(alpha: 0.9),
        foregroundColor: Colors.white,
        elevation: 0,
         bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search materials...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Predictive Forecast',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForecastScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.secondary,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditMaterialScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Material'),
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: AppTheme.mainGradient,
        ),
        child: SafeArea(
          child: StreamBuilder<List<RawMaterialModel>>(
            stream: database.getRawMaterials(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allMaterials = snapshot.data ?? [];
              final materials = allMaterials.where((m) => m.name.toLowerCase().contains(_searchQuery)).toList();

              if (materials.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(allMaterials.isEmpty ? 'No raw materials found' : 'No matching results'),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   // Forecast Section
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: StockService().getStockForecast(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                      
                      final criticalItems = snapshot.data!.where((i) => (i['daysLeft'] as int) < 7).toList();
                      if (criticalItems.isEmpty) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             const Padding(
                               padding: EdgeInsets.only(left: 4, bottom: 8),
                               child: Text('⚠️ Critical Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                             ),
                             SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: criticalItems.length,
                                separatorBuilder: (_,__) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final item = criticalItems[index];
                                  final int days = item['daysLeft'];
                                  final bool isCritical = days < 3;
                                  
                                  return Container(
                                    width: 150,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isCritical ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isCritical ? Colors.red.shade200 : Colors.orange.shade200),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.timer, size: 14, color: isCritical ? Colors.red : Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$days Days Left', 
                                              style: TextStyle(
                                                color: isCritical ? Colors.red : Colors.orange, 
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13
                                              )
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rate: ${item['dailyUsage'].toStringAsFixed(1)} kg/day',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Inventory List
                  ...materials.map((item) {
                     final isLowStock = item.currentStock <= item.minimumThreshold;
                     return Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [
                           BoxShadow(
                             color: isLowStock ? Colors.red.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                             blurRadius: 8,
                             offset: const Offset(0, 4)
                           )
                         ],
                         border: isLowStock ? Border.all(color: Colors.red.shade100, width: 1.5) : null,
                       ),
                       child: InkWell(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RawMaterialHistoryScreen(material: item))),
                         borderRadius: BorderRadius.circular(16),
                         child: Padding(
                           padding: const EdgeInsets.all(16),
                           child: Row(
                             children: [
                               Container(
                                 width: 50,
                                 height: 50,
                                 decoration: BoxDecoration(
                                   color: isLowStock ? Colors.red.shade50 : AppTheme.primary.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Icon(
                                   Icons.inventory_2,
                                   color: isLowStock ? Colors.red : AppTheme.primary,
                                 ),
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       item.name,
                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                     ),
                                     const SizedBox(height: 4),
                                     Wrap(
                                       spacing: 8,
                                       children: [
                                         _buildTag(Icons.store, item.supplierName),
                                         _buildTag(Icons.place, item.storageLocation),
                                       ],
                                     ),
                                   ],
                                 ),
                               ),
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.end,
                                 children: [
                                   Text(
                                     '${item.currentStock}',
                                     style: TextStyle(
                                       fontWeight: FontWeight.bold,
                                       fontSize: 20,
                                       color: isLowStock ? Colors.red : AppTheme.textPrimary,
                                     ),
                                   ),
                                   Text(
                                     item.unit,
                                     style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                   ),
                                 ],
                               ),
                               const SizedBox(width: 8),
                               IconButton(
                                 icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                 onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AddEditMaterialScreen(material: item)),
                                    );
                                 },
                               ),
                             ],
                           ),
                         ),
                       ),
                     );
                  }),
                  
                  // Add extra padding at bottom for FAB
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildTag(IconData icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
