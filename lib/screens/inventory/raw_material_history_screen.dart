import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/namkeen_theme.dart';
import '../../models/raw_material_model.dart';
import '../../models/assignment_model.dart';
import '../../services/database_service.dart';

class RawMaterialHistoryScreen extends StatelessWidget {
  final RawMaterialModel material;
  const RawMaterialHistoryScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${material.name} History'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Stock', style: TextStyle(color: Colors.grey[600])),
                            Text('${material.currentStock} ${material.unit}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                             Text('Storage Location', style: TextStyle(color: Colors.grey[600])),
                             Text(material.storageLocation, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Supplier: ${material.supplierName}'),
                        Text('Cost: ₹${material.costPerUnit}/${material.unit}'),
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text('Supply Log (Inward)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.arrow_downward, color: Colors.white, size: 16)),
                title: const Text('Initial / Last Supply Received'),
                subtitle: Text('Added on ${DateFormat.yMMMd().format(material.assignedDate)}'),
                trailing: Text('+${material.currentStock} ${material.unit}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), // Simple estimation
              ),
            ),

            const SizedBox(height: 24),
            const Text('Usage History (Outward)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // We need to query assignments where this material was used.
            // Since Firestore query inside array of objects is tricky without specific index or structure,
            // we will fetch assignments and filter client-side for this MVP or use a dedicated collection if scaled.
            // For now: Fetch all assignments (or recent ones) and filter.
            StreamBuilder<List<AssignmentModel>>(
              stream: db.getAssignments(), // Ideally pass a filter/limit
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final assignments = snapshot.data ?? [];
                
                // Filter where materialsUsed contains this material ID
                final usage = assignments.where((a) {
                  return a.materialsUsed.any((m) => m['materialId'] == material.id || m['name'] == material.name);
                }).toList();

                if (usage.isEmpty) {
                  return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No usage recorded yet.'))));
                }

                // Sort by date desc
                usage.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: usage.length,
                  itemBuilder: (context, index) {
                    final task = usage[index];
                    // Find the specific usage entry
                    final matEntry = task.materialsUsed.firstWhere((m) => m['materialId'] == material.id || m['name'] == material.name, orElse: () => {});
                    final qty = matEntry['quantity'] ?? '0';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.arrow_upward, color: Colors.white, size: 16)),
                        title: Text('Used in ${task.type}'),
                        subtitle: Text('Batch: ${task.batchId} • ${DateFormat.yMMMd().format(task.assignedAt)}'),
                        trailing: Text('-$qty ${material.unit}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
