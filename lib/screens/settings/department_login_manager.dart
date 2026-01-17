import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/department_account_model.dart';
import '../../services/database_service.dart';

class DepartmentLoginManager extends StatelessWidget {
  const DepartmentLoginManager({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Logins'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(context, null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<DepartmentAccountModel>>(
        stream: db.getDepartmentAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) return const Center(child: Text('No department accounts found.\nTap + to create one.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: account.isActive ? Colors.green : Colors.grey,
                    child: Icon(Icons.badge, color: Colors.white),
                  ),
                  title: Text(account.departmentName),
                  subtitle: Text('ID: ${account.username} • Role: ${account.role}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAccountDialog(context, account),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                           // Confirm delete
                           final confirm = await showDialog<bool>(
                             context: context,
                             builder: (ctx) => AlertDialog(
                               title: const Text('Delete Account?'),
                               content: const Text('This action cannot be undone.'),
                               actions: [
                                 TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                 TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                               ],
                             )
                           );
                           if (confirm == true) {
                             await db.deleteDepartmentAccount(account.id);
                           }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAccountDialog(BuildContext context, DepartmentAccountModel? account) {
    final nameCtrl = TextEditingController(text: account?.departmentName);
    final roleCtrl = TextEditingController(text: account?.role ?? 'Worker');
    // Using simple username/password for MVP demo as requested (fast one go)
    // Username is often same as Dept Name
    final passCtrl = TextEditingController(text: account?.password);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? 'Create Account' : 'Edit Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Department Name (e.g. Packing)')),
               const SizedBox(height: 12),
               TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Login Password')),
               const SizedBox(height: 12),
               DropdownButtonFormField<String>(
                 value: ['Admin', 'Supervisor', 'Worker', 'Dispatch', 'accounts'].contains(roleCtrl.text) ? roleCtrl.text : 'Worker',
                 decoration: const InputDecoration(labelText: 'Role'),
                 items: const [
                   DropdownMenuItem<String>(value: 'Admin', child: Text('Admin (Full Access)')),
                   DropdownMenuItem<String>(value: 'Supervisor', child: Text('Supervisor (Logs + Tasks)')),
                   DropdownMenuItem<String>(value: 'Worker', child: Text('Worker (Reference Only)')),
                   DropdownMenuItem<String>(value: 'Dispatch', child: Text('Dispatch Only')),
                 ],
                 onChanged: (val) => roleCtrl.text = val!,
               )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
               if (nameCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
               
               final db = Provider.of<DatabaseService>(context, listen: false);
               final newAccount = DepartmentAccountModel(
                 id: account?.id ?? '', // empty for new
                 departmentName: nameCtrl.text.trim(),
                 username: nameCtrl.text.trim(), // Using dept name as username
                 password: passCtrl.text.trim(),
                 role: roleCtrl.text,
                 isActive: true,
               );

               if (account == null) {
                 await db.addDepartmentAccount(newAccount);
               } else {
                 await db.updateDepartmentAccount(newAccount);
               }
               if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }
}
