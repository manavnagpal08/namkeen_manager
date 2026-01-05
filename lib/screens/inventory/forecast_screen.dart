import 'package:flutter/material.dart';
import '../../core/namkeen_theme.dart';
import '../../services/inventory_logic_service.dart';
import '../../models/raw_material_model.dart';
import '../../core/glass_container.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We instantiate the logic service directly or via provider if registered.
    // Assuming simple instantiation for now as it uses Firestore instance internally.
    final logicService = InventoryLogicService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Requirement Forecast'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.mainGradient,
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: logicService.calculateRawMaterialRequirements(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final data = snapshot.data ?? [];

            if (data.isEmpty) {
              return Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 48, color: Colors.green),
                      SizedBox(height: 16),
                      Text('All Raw Materials Sufficient!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('No deficits found for pending orders.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final material = item['material'] as RawMaterialModel;
                final required = item['required'] as double;
                final deficit = item['deficit'] as double;
                final stock = item['stock'] as double;

                final isDeficit = deficit > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDeficit ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDeficit ? Icons.warning : Icons.check, 
                            color: isDeficit ? Colors.red : Colors.green
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(material.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Stock: ${stock.toStringAsFixed(2)} ${material.unit}', style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Required: ${required.toStringAsFixed(2)} ${material.unit}', style: const TextStyle(fontSize: 12)),
                            if (isDeficit)
                              Text(
                                'Short: ${deficit.toStringAsFixed(2)} ${material.unit}',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
