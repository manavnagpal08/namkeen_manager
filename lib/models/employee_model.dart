class EmployeeModel {
  final String id;
  final String name;
  final String phone;
  final String role; // mixing, frying, packing, dispatch, inventory, storage_in_charge
  final bool isActive;
  final double salary;
  final double baseSalary;
  final String address;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.salary = 0.0,
    this.baseSalary = 0.0,
    this.address = '',
  });

  factory EmployeeModel.fromMap(String id, Map<String, dynamic> data) {
    return EmployeeModel(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'worker',
      isActive: data['is_active'] ?? true,
      salary: (data['salary'] ?? 0).toDouble(),
      baseSalary: (data['base_salary'] ?? 0).toDouble(),
      address: data['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'salary': salary,
      'base_salary': baseSalary,
      'address': address,
    };
  }
}
