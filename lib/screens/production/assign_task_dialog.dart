import 'package:flutter/material.dart';
import '../../models/batch_model.dart';
import '../../models/employee_model.dart';
import '../../models/assignment_model.dart';
import '../../services/database_service.dart';

class AssignTaskDialog extends StatefulWidget {
  final BatchModel batch;
  final DatabaseService db;

  const AssignTaskDialog({super.key, required this.batch, required this.db});

  @override
  State<AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends State<AssignTaskDialog> {
  String? _selectedEmployeeId;
  String _taskType = 'Packaging'; // Manufacturing or Packaging
  final _targetCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Batch: ${widget.batch.batchCode}'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _taskType,
              items: ['Manufacturing', 'Packaging'].map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _taskType = val!),
              decoration: const InputDecoration(labelText: 'Task Type'),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<EmployeeModel>>(
              stream: widget.db.getEmployees(),
              builder: (context, snapshot) {
                final employees = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedEmployeeId,
                  hint: const Text('Select Employee'),
                  items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e.id, child: Text('${e.name} (${e.role})'))).toList(),
                  onChanged: (val) => setState(() => _selectedEmployeeId = val),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Quantity (Units/Kg)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (_selectedEmployeeId == null) return;
            
            final assignment = AssignmentModel(
              id: '',
              batchId: widget.batch.id,
              employeeId: _selectedEmployeeId!,
              type: _taskType,
              targetQuantity: double.tryParse(_targetCtrl.text) ?? 0,
              assignedAt: DateTime.now(),
            );
            
            await widget.db.addAssignment(assignment);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Assign'),
        )
      ],
    );
  }
}
