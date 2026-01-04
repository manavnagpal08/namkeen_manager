class DepartmentAccountModel {
  final String id;
  final String departmentName; // e.g. "Production", "Packaging"
  final String username;
  final String password; // In real app, hash this!
  final String role; // "Admin", "Supervisor", "Worker", "Dispatch"
  final bool isActive;

  DepartmentAccountModel({
    required this.id,
    required this.departmentName,
    required this.username,
    required this.password,
    required this.role,
    this.isActive = true,
  });

  factory DepartmentAccountModel.fromMap(String id, Map<String, dynamic> data) {
    return DepartmentAccountModel(
      id: id,
      departmentName: data['department'] ?? 'Unknown',
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      role: data['role'] ?? 'Worker',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'department': departmentName,
      'username': username,
      'password': password,
      'role': role,
      'isActive': isActive,
    };
  }
}
