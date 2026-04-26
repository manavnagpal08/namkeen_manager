import 'package:flutter/foundation.dart';
import '../models/employee_model.dart';
import '../models/department_account_model.dart'; // Import this
import 'database_service.dart';

class AuthService with ChangeNotifier {
  EmployeeModel? _currentUser; // Legacy support if needed, but we should switch to Account
  DepartmentAccountModel? _currentAccount;
  bool _isAuthenticated = false;

  EmployeeModel? get currentUser => _currentUser;
  DepartmentAccountModel? get currentAccount => _currentAccount; 
  bool get isAuthenticated => _isAuthenticated;
  
  final DatabaseService _db = DatabaseService();

  Future<bool> login(String department, String password) async {
    // 1. Check Hardcoded Admin for initial setup safety
    if ((department == 'Admin' || department == 'Admin2' || department == 'admin2') && password == 'admin') {
       _currentAccount = DepartmentAccountModel(
         id: 'admin_sys_${department.toLowerCase()}',
         departmentName: department,
         username: department.toLowerCase(),
         password: 'hashed',
         role: 'Admin'
       );
       _isAuthenticated = true;
       notifyListeners();
       return true;
    }

    // 2. Check Firestore
    try {
      final account = await _db.verifyLogin(department, password);
      if (account != null) {
        _currentAccount = account;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Login Error: $e');
    }

    notifyListeners();
    return false;
  }

  void logout() {
    _currentUser = null;
    _currentAccount = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
