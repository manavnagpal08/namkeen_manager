import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/namkeen_theme.dart';
import '../../models/raw_material_model.dart';
import '../../models/assignment_model.dart';
// import '../../core/glass_container.dart'; // Removing unused import

class RawMaterialHistoryScreen extends StatelessWidget {
  final RawMaterialModel material;
  const RawMaterialHistoryScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${material.name} History'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRestockDialog(context),
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Restock / Inward'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('raw_materials')
            .doc(material.id)
            .collection('history')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.hasData ? snapshot.data!.docs : [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
               // 1. Live Header
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('raw_materials').doc(material.id).snapshots(),
                builder: (context, headerSnap) {
                  if (!headerSnap.hasData || !headerSnap.data!.exists) return _buildHeaderCard(material); 
                  final liveMaterial = RawMaterialModel.fromMap(headerSnap.data!.id, headerSnap.data!.data() as Map<String, dynamic>);
                  return _buildHeaderCard(liveMaterial);
                },
              ),

               const SizedBox(height: 24),
               const Text('Transaction Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
               const SizedBox(height: 12),
               
               if (logs.isEmpty) 
                 const Padding(
                   padding: EdgeInsets.all(32.0),
                   child: Center(child: Text("No history yet", style: TextStyle(color: Colors.grey))),
                 )
               else
                 ...logs.map((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   final double change = (data['changeAmount'] ?? 0).toDouble();
                   final bool isPositive = change > 0;
                   final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                   final reason = data['reason'] ?? 'Manual Update';
                   
                   return Container(
                     margin: const EdgeInsets.only(bottom: 12),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0,2))],
                     ),
                     child: ListTile(
                       leading: CircleAvatar(
                         backgroundColor: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                         child: Icon(
                           isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                           color: isPositive ? Colors.green : Colors.red,
                           size: 20,
                         ),
                       ),
                       title: Text(reason, style: const TextStyle(fontWeight: FontWeight.w600)),
                       subtitle: Text(DateFormat('MMM d, y • h:mm a').format(date)),
                       trailing: Text(
                         '${isPositive ? '+' : ''}$change ${material.unit}',
                         style: TextStyle(
                           color: isPositive ? Colors.green : Colors.red,
                           fontWeight: FontWeight.bold,
                           fontSize: 16,
                       ),
                     ),
                   ),
                 );
               }), 

               // Legacy Usage Section
               const SizedBox(height: 24),
               const Divider(),
               const Text('Legacy Usage (Pre-Automation)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
               const SizedBox(height: 12),
               StreamBuilder<QuerySnapshot>(
                 stream: FirebaseFirestore.instance.collection('assignments').snapshots(),
                 builder: (context, assignmentSnap) {
                    if (!assignmentSnap.hasData) return const Center(child: CircularProgressIndicator());
                    final allAssignments = assignmentSnap.data!.docs.map((d) => AssignmentModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();
                    
                    // Filter
                    final usage = allAssignments.where((a) {
                       return a.materialsUsed.any((m) => m['materialId'] == material.id || m['name'] == material.name);
                    }).toList();
                    usage.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

                    if (usage.isEmpty) return const SizedBox.shrink(); // Hide if empty so we don't clutter

                    return Column(
                      children: usage.map((task) {
                        final matEntry = task.materialsUsed.firstWhere((m) => m['materialId'] == material.id || m['name'] == material.name, orElse: () => {});
                        final qty = matEntry['quantity'] ?? '0';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.orange.withValues(alpha: 0.2), child: const Icon(Icons.history, color: Colors.orange, size: 16)),
                            title: Text('Used in ${task.type}'),
                            subtitle: Text('Batch: ${task.batchCode.isNotEmpty ? task.batchCode : task.batchId} • ${DateFormat.yMMMd().format(task.assignedAt)}'),
                            trailing: Text('-$qty ${material.unit}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          ),
                        );
                      }).toList(),
                    );
                 },
               ),
               const SizedBox(height: 80), // Fab space
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(RawMaterialModel displayMaterial) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayMaterial.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${displayMaterial.storageLocation} • ${displayMaterial.supplierName}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Stock', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${displayMaterial.currentStock} ${displayMaterial.unit}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.white.withValues(alpha: 0.2),
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: const Text('Live Updates', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }



  void _showRestockDialog(BuildContext context) {
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: material.costPerUnit.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receiving Supply'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add new stock to inventory.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity Received (${material.unit})', 
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.add_shopping_cart),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Updated Cost (Optional)', 
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text);
              if (qty == null || qty <= 0) return;
              
              Navigator.pop(context);
              
              try {
                final db = FirebaseFirestore.instance;
                final ref = db.collection('raw_materials').doc(material.id);
                
                await db.runTransaction((transaction) async {
                   final snap = await transaction.get(ref);
                   if (!snap.exists) return;
                   
                   final current = (snap.get('currentStock') ?? 0).toDouble();
                   final newStock = current + qty;
                   final newCost = double.tryParse(costCtrl.text) ?? material.costPerUnit;

                   transaction.update(ref, {
                     'currentStock': newStock,
                     'costPerUnit': newCost,
                   });
                   
                   final historyRef = ref.collection('history').doc();
                   transaction.set(historyRef, {
                      'date': DateTime.now(),
                      'changeAmount': qty,
                      'reason': 'Stock Inward / Supply',
                      'newStock': newStock,
                      'isAddition': true,
                   });
                });
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock Updated Successfully')));
                  Navigator.pop(context); // Go back to list to refresh stock or stay? Stay is better but model needs update.
                  // Since we passed 'material' model, it won't update in this view unless we re-fetch or pop.
                  // We'll pop to refresh the previous screen.
                }

              } catch (e) {
                 debugPrint('Error : $e');
              }
            }, 
            child: const Text('Confirm Received'),
          ),
        ],
      ),
    );
  }
}
