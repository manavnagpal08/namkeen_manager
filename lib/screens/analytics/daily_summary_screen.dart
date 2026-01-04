import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/namkeen_theme.dart';
import '../../models/assignment_model.dart';
import '../../models/batch_model.dart';
import '../../services/database_service.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1)); // Default to Yesterday

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Summary'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.grey),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.yMMMd().format(_selectedDate),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  onPressed: () {
                    if (_selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month) return;
                    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<BatchModel>>(
              stream: db.getBatches(),
              builder: (context, batchSnap) {
                final batches = batchSnap.data ?? [];
                final batchMap = {for (var b in batches) b.id: b.batchCode};

                return StreamBuilder<List<AssignmentModel>>(
                  stream: db.getAssignments(),
                  builder: (context, assignSnap) {
                    if (assignSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    final allAssignments = assignSnap.data ?? [];
                    // Filter by Date (Completed At matches selected date)
                    final dailyTasks = allAssignments.where((t) {
                      if (t.status != 'Completed') return false;
                      final d = t.completedAt ?? t.assignedAt; 
                      return d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
                    }).toList();

                    return StreamBuilder<List<OrderModel>>(
                      stream: db.getOrdersStream(),
                      builder: (context, orderSnap) {
                        final orders = orderSnap.data ?? [];

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildSalesAnalysis(orders), // New Analytics Section
                            const SizedBox(height: 24),
                            _buildSummaryStats(dailyTasks),
                            const SizedBox(height: 24),
                            _buildSectionHeader('Manufacturing Tasks', Colors.orange),
                            const SizedBox(height: 8),
                            _buildTaskList(dailyTasks.where((t) => t.type == 'Manufacturing').toList(), Colors.orange, batchMap),
                            const SizedBox(height: 24),
                            _buildSectionHeader('Packaging Tasks', Colors.blue),
                            const SizedBox(height: 8),
                             _buildTaskList(dailyTasks.where((t) => t.type == 'Packaging').toList(), Colors.blue, batchMap),
                          ],
                        );
                      }
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesAnalysis(List<OrderModel> allOrders) {
    if (allOrders.isEmpty) return const SizedBox.shrink();

    // 1. Filter Last 30 Days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recentOrders = allOrders.where((o) => o.date.isAfter(cutoff)).toList();

    if (recentOrders.isEmpty) return const SizedBox.shrink();

    // 2. Aggregate Sales
    final salesMap = <String, double>{};
    for (var order in recentOrders) {
      for (var item in order.items) {
        // Use name if available, else ID
        final key = item.productName.isNotEmpty ? item.productName : item.productId;
        salesMap[key] = (salesMap[key] ?? 0) + item.quantity;
      }
    }

    // 3. Sort
    final sortedEntries = salesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Descending

    if (sortedEntries.isEmpty) return const SizedBox.shrink();

    final top5 = sortedEntries.take(5).toList();
    final bottom5 = sortedEntries.length > 5 ? sortedEntries.reversed.take(5).toList() : <MapEntry<String, double>>[];
    
    // Max value for progress bar logic
    final double maxVal = top5.isNotEmpty ? top5.first.value : 1;

    return Column(
      children: [
        _buildSectionHeader('Sales Insights (Last 30 Days)', AppTheme.primary),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔥 Top 5 Best Sellers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...top5.map((e) => _buildSalesRow(e.key, e.value, maxVal, Colors.green)),
              
              if (bottom5.isNotEmpty) ...[
                const Divider(height: 32),
                const Text('📉 Slowest Moving Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...bottom5.map((e) => _buildSalesRow(e.key, e.value, maxVal, Colors.redAccent)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesRow(String name, double value, double max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: (value / max).clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 50,
            child: Text('${value.toInt()} units', style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: color, margin: const EdgeInsets.only(right: 8)),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildSummaryStats(List<AssignmentModel> tasks) {
    double totalMfg = 0;
    double totalPkg = 0;
    
    for(var t in tasks) {
      if (t.type == 'Manufacturing') totalMfg += t.completedUnits;
      if (t.type == 'Packaging') totalPkg += t.completedUnits;
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard('Manufacturing', '${totalMfg.toStringAsFixed(1)} kg', Colors.orange, Icons.whatshot)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Packaging', '${totalPkg.toStringAsFixed(0)} pkts', Colors.blue, Icons.inventory_2)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<AssignmentModel> tasks, Color accentColor, Map<String, String> batchMap) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No tasks recorded.', style: TextStyle(color: Colors.grey[400])),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_,__) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final bCode = task.batchCode.isNotEmpty ? task.batchCode : (batchMap[task.batchId] ?? task.batchId);

        return InkWell(
          onTap: () {
             // Optional: Show Task Details
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: accentColor.withValues(alpha: 0.1),
                child: Icon(Icons.check, color: accentColor, size: 20), 
              ),
              title: Text('Batch: $bCode', style: const TextStyle(fontWeight: FontWeight.bold)), 
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Produced: ${task.completedUnits} ${(task.type=='Manufacturing'?'kg':'pkts')}\n'
                  '${task.completedAt != null ? DateFormat.jm().format(task.completedAt!) : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      },
    );
  }
}
