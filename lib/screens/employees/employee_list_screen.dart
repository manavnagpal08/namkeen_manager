import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/employee_model.dart';
import '../../services/database_service.dart';

class EmployeeListScreen extends StatelessWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.secondary,
        onPressed: () => _showAddEditDialog(context, db),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<EmployeeModel>>(
        stream: db.getEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final employees = snapshot.data ?? [];
          
          if (employees.isEmpty) return const Center(child: Text('No employees added.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(emp.name[0])),
                  title: Text(emp.name),
                  subtitle: Text('${emp.role} • ${emp.phone}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showAddEditDialog(context, db, employee: emp),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, DatabaseService db, {EmployeeModel? employee}) {
    final nameCtrl = TextEditingController(text: employee?.name ?? '');
    final phoneCtrl = TextEditingController(text: employee?.phone ?? '');
    String role = employee?.role ?? 'Worker';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(employee == null ? 'Add Employee' : 'Edit Employee'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['Worker', 'Supervisor', 'Mixing', 'Frying', 'Packing', 'Dispatch', 'Inventory']
                      .map<DropdownMenuItem<String>>((r) => DropdownMenuItem<String>(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setState(() => role = val!),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final emp = EmployeeModel(
                    id: employee?.id ?? '',
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    role: role,
                    isActive: true,
                  );
                  if (employee == null) {
                    await db.addEmployee(emp);
                  } else {
                    await db.updateEmployee(emp);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              )
            ],
          );
        }
      ),
    );
  }
}
