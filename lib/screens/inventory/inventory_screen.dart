import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../core/glass_container.dart';
import '../../models/raw_material_model.dart';
import '../../services/database_service.dart';
import 'add_edit_material_screen.dart';
import 'raw_material_history_screen.dart';
import '../../services/stock_service.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Material Inventory'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.secondary,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditMaterialScreen()));
        },
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: AppTheme.mainGradient,
        ),
        child: StreamBuilder<List<RawMaterialModel>>(
          stream: database.getRawMaterials(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                ),
              );
            }

            final materials = snapshot.data ?? [];

            if (materials.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No raw materials found'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditMaterialScreen()));
                      },
                      child: const Text('Add First Material'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final item = materials[index];
                final isLowStock = item.currentStock <= item.minimumThreshold;

                return InkWell(
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => RawMaterialHistoryScreen(material: item)));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  borderRadius: 16,
                  color: Colors.white,
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isLowStock ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory,
                          color: isLowStock ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Forecast Section
          FutureBuilder<List<Map<String, dynamic>>>(
            future: StockService().getStockForecast(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
              
              final criticalItems = snapshot.data!.where((i) => (i['daysLeft'] as int) < 7).toList();
              if (criticalItems.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Stock Forecast Alert', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: criticalItems.length,
                        separatorBuilder: (_,__) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = criticalItems[index];
                          final int days = item['daysLeft'];
                          final bool isCritical = days < 3;
                          
                          return Container(
                            width: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isCritical ? Colors.red.shade200 : Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                  '$days Days Left', 
                                  style: TextStyle(
                                    color: isCritical ? Colors.red : Colors.orange, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12
                                  )
                                ),
                                Text(
                                  'Usage: ${item['dailyUsage'].toStringAsFixed(1)} kg/day',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
          
          Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${item.storageLocation} • Supplier: ${item.supplierName}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.currentStock} ${item.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isLowStock ? Colors.red : AppTheme.textPrimary,
                            ),
                          ),
                          if (isLowStock)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('LOW STOCK', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddEditMaterialScreen(material: item)),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ));
              },
            );
          },
        ),
      ),
    );
  }
}
