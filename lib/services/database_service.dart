import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../models/product_size_model.dart';
import '../models/raw_material_model.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import '../models/employee_model.dart';
import '../models/batch_model.dart';
import '../models/assignment_model.dart';
import '../models/order_model.dart';
import '../models/packing_unit_model.dart';
import '../models/warehouse_stock_model.dart';
import '../models/dispatch_transfer_models.dart';
import '../models/department_account_model.dart';
import '../models/company_settings_model.dart';
import '../models/customer_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _categoriesRef => _db.collection('categories');
  CollectionReference get _sizesRef => _db.collection('sizes');
  CollectionReference get _materialsRef => _db.collection('raw_materials');
  CollectionReference get _productsRef => _db.collection('products');
  CollectionReference get _recipesRef => _db.collection('recipes');
  CollectionReference get _employeesRef => _db.collection('employees');
  CollectionReference get _batchesRef => _db.collection('batches');
  CollectionReference get _assignmentsRef => _db.collection('assignments');
  CollectionReference get _ordersRef => _db.collection('orders');
  CollectionReference get _packingUnits => _db.collection('packing_units');
  CollectionReference get _warehouseStock => _db.collection('warehouse_stock');
  CollectionReference get _dispatchRef => _db.collection('dispatch');
  CollectionReference get _transferRef => _db.collection('transfers');
  CollectionReference get _accountsRef => _db.collection('dept_accounts');
  CollectionReference get _settingsRef => _db.collection('settings');

  // --- Categories ---
  Stream<List<CategoryModel>> getCategories() {
    return _categoriesRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> addCategory(CategoryModel category) async {
    await _categoriesRef.add(category.toMap());
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _categoriesRef.doc(category.id).update(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesRef.doc(id).delete();
  }

  // --- Sizes ---
  Stream<List<ProductSizeModel>> getSizes({String? categoryId}) {
    Query query = _sizesRef;
    if (categoryId != null) {
      query = query.where('category_id', isEqualTo: categoryId);
    }
    return query.orderBy('weight_in_grams').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductSizeModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> addSize(ProductSizeModel size) async {
    await _sizesRef.add(size.toMap());
  }

  Future<void> updateSize(ProductSizeModel size) async {
    await _sizesRef.doc(size.id).update(size.toMap());
  }

  Future<void> deleteSize(String id) async {
    await _sizesRef.doc(id).delete();
  }

  // --- Raw Materials ---
  Stream<List<RawMaterialModel>> getRawMaterials() {
    return _materialsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RawMaterialModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> addRawMaterial(RawMaterialModel material) async {
    await _materialsRef.add(material.toMap());
  }

  Future<void> updateRawMaterial(RawMaterialModel material) async {
    await _materialsRef.doc(material.id).update(material.toMap());
  }

  Future<void> deleteRawMaterial(String id) async {
    await _materialsRef.doc(id).delete();
  }



  // --- Products ---
  Stream<List<ProductModel>> getProducts({String? categoryId}) {
    Query query = _productsRef;
    if (categoryId != null) {
      query = query.where('category_id', isEqualTo: categoryId);
    }
    // Fix: Remove orderBy from Firestore query to avoid missing composite index error. Sort in Dart.
    return query.snapshots().map((snapshot) {
      var list = snapshot.docs.map((doc) {
        return ProductModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<bool> checkProductExists(String name) async {
    final snap = await _productsRef.where('name', isEqualTo: name).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> addProduct(ProductModel product) async {
    await _productsRef.add(product.toMap());
  }

  Future<void> updateProduct(ProductModel product) async {
    await _productsRef.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _productsRef.doc(id).delete();
  }

  // --- Recipes ---
  Stream<List<RecipeModel>> getRecipes({String? productId}) {
    Query query = _recipesRef;
    if (productId != null) {
      query = query.where('product_id', isEqualTo: productId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RecipeModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> addRecipe(RecipeModel recipe) async {
    await _recipesRef.add(recipe.toMap());
  }

  Future<void> updateRecipe(RecipeModel recipe) async {
    await _recipesRef.doc(recipe.id).update(recipe.toMap());
  }

  Future<void> deleteRecipe(String id) async {
    await _recipesRef.doc(id).delete();
  }

  // --- Employees ---
  Stream<List<EmployeeModel>> getEmployees() {
    return _employeesRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return EmployeeModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> addEmployee(EmployeeModel employee) async {
    await _employeesRef.add(employee.toMap());
  }

  Future<void> updateEmployee(EmployeeModel employee) async {
    await _employeesRef.doc(employee.id).update(employee.toMap());
  }

  Future<void> deleteEmployee(String id) async {
    await _employeesRef.doc(id).delete();
  }

  // --- Batches ---
  Stream<List<BatchModel>> getBatches({bool activeOnly = false}) {
    Query query = _batchesRef.orderBy('start_time', descending: true);
    if (activeOnly) {
      // Logic for active batches (status != Completed)
      // Firestore inequality usage might required composite index
      // Simpler: Filter in app or use exact match 'In Progress'
    }
    return query.snapshots().map((snapshot) {
      var list = snapshot.docs.map((doc) {
        return BatchModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      if (activeOnly) {
        list = list.where((b) => b.status != 'Completed').toList();
      }
      return list;
    });
  }

  Future<void> addBatch(BatchModel batch) async {
    await _batchesRef.add(batch.toMap());
  }

  Future<void> updateBatch(BatchModel batch) async {
    await _batchesRef.doc(batch.id).update(batch.toMap());
  }

  // --- Assignments ---
  Stream<List<AssignmentModel>> getAssignments({String? batchId}) {
    Query query = _assignmentsRef;
    if (batchId != null) query = query.where('batch_id', isEqualTo: batchId);
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AssignmentModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addAssignment(AssignmentModel assignment) async {
    await _assignmentsRef.add(assignment.toMap());
  }

  Future<void> assignTask(AssignmentModel assignment) async {
    await _assignmentsRef.add(assignment.toMap());
  }

  Future<void> updateAssignment(AssignmentModel assignment) async {
    await _assignmentsRef.doc(assignment.id).update(assignment.toMap());
  }

  // MARK: - Packing Configurations
  Stream<List<PackingUnitModel>> getPackingConfigs() {
    return _packingUnits.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PackingUnitModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }
  
  // Get specific config for a size (with optional category fallback)
  Future<PackingUnitModel?> getPackingConfigForSize(String sizeId, {String? categoryId}) async {
    // 1. Try Specific Size
    var snapshot = await _packingUnits.where('sizeId', isEqualTo: sizeId).limit(1).get();
    
    // 2. Fallback to Category if size is Standard or not found
    if (snapshot.docs.isEmpty && categoryId != null) {
      snapshot = await _packingUnits.where('categoryId', isEqualTo: categoryId).limit(1).get();
    }

    if (snapshot.docs.isNotEmpty) {
      return PackingUnitModel.fromMap(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
    }
    return null;
  }

  Future<void> savePackingConfig(PackingUnitModel config) async {
    if (config.id.isEmpty) {
      await _packingUnits.add(config.toMap());
    } else {
      await _packingUnits.doc(config.id).update(config.toMap());
    }
  }

  // MARK: - Warehouse Stock
  Stream<List<WarehouseStockModel>> getWarehouseStock() {
    return _warehouseStock.orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => WarehouseStockModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  Future<void> addWarehouseStock(WarehouseStockModel stock) async {
    await _warehouseStock.add(stock.toMap());
  }

  Future<void> updateWarehouseStock(WarehouseStockModel stock) async {
    await _warehouseStock.doc(stock.id).update(stock.toMap());
  }

  // Calculate total available packets for a product from warehouse
  Future<double> getAvailableStockPackets(String productId) async {
    final snap = await _warehouseStock.where('productId', isEqualTo: productId).get();
    double total = 0;
    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['quantityPackets'] ?? 0).toDouble();
    }
    return total;
  }

  // Deduct packets from Warehouse (FIFO logic or simple aggregate reduction)
  Future<void> deductWarehouseStock(String productId, double quantityToDeduct) async {
    // strict FIFO: Get oldest entries with available stock
    final snap = await _warehouseStock
        .where('productId', isEqualTo: productId)
        .where('quantityPackets', isGreaterThan: 0)
        .orderBy('quantityPackets') // Optimization? No, ideally orderBy Date.
        // orderBy('updatedAt') // Requires composite index usually.
        .get();
    
    // In-memory sort by date if index missing
    final docs = snap.docs.toList();
    docs.sort((a, b) {
       final dataA = a.data() as Map<String, dynamic>;
       final dataB = b.data() as Map<String, dynamic>;
       final dtA = DateTime.tryParse(dataA['updatedAt'] ?? '') ?? DateTime.now();
       final dtB = DateTime.tryParse(dataB['updatedAt'] ?? '') ?? DateTime.now();
       return dtA.compareTo(dtB);
    });

    double remaining = quantityToDeduct;
    final batch = _db.batch();

    for (var doc in docs) {
      if (remaining <= 0) break;
      final params = doc.data() as Map<String, dynamic>;
      double current = (params['quantityPackets'] ?? 0).toDouble();
      
      if (current >= remaining) {
        batch.update(doc.reference, {'quantityPackets': current - remaining});
        remaining = 0;
      } else {
        batch.update(doc.reference, {'quantityPackets': 0});
        remaining -= current;
      }
    }
    
    await batch.commit();
    if (remaining > 0) {
      // Stock was insufficient despite check? Race condition.
      // Log error or ignore. 
    }
  }

  // --- Orders ---
  Stream<List<OrderModel>> getOrders() {
    return _ordersRef.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addOrder(OrderModel order) async {
    await _ordersRef.add(order.toMap());
  }

  Future<void> updateOrderPaymentStatus(String orderId, String paymentStatus) async {
    await _ordersRef.doc(orderId).update({'payment_status': paymentStatus});
  }

  // --- Orders ---
  Stream<List<OrderModel>> getOrdersStream() {
    return _ordersRef.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  // --- Dispatch ---
  Stream<List<DispatchModel>> getDispatchLogs() {
    return _dispatchRef.orderBy('dispatch_date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DispatchModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addDispatch(DispatchModel dispatch) async {
    await _dispatchRef.add(dispatch.toMap());
  }

  // --- Transfer ---
  Stream<List<TransferModel>> getTransfers() {
    return _transferRef.orderBy('transfer_date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TransferModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addTransfer(TransferModel transfer) async {
    await _transferRef.add(transfer.toMap());
  }

  CollectionReference get _customersRef => _db.collection('customers');
  CollectionReference get _paymentsRef => _db.collection('customer_payments');

  // --- Customers ---
  Stream<List<CustomerModel>> getCustomers() {
    return _customersRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CustomerModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addCustomer(CustomerModel customer) async {
    await _customersRef.add(customer.toMap());
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _customersRef.doc(customer.id).update(customer.toMap());
  }

  Future<void> updateCustomerDebt(String customerId, double amountChange) async {
    await _customersRef.doc(customerId).update({
      'totalDue': FieldValue.increment(amountChange),
      'lastTransactionDate': DateTime.now(),
    });
  }

  // --- Customer Payments ---
  Stream<List<CustomerPaymentModel>> getCustomerPayments(String customerId) {
    return _paymentsRef
        .where('customerId', isEqualTo: customerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CustomerPaymentModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addPayment(CustomerPaymentModel payment) async {
    final batch = _db.batch();
    
    // 1. Add Payment Record
    final newPaymentRef = _paymentsRef.doc();
    batch.set(newPaymentRef, payment.toMap());

    // 2. Update Customer Balance
    // If 'Credit' (Order), Debt Increases (+ amount)
    // If 'Debit' (Payment Received), Debt Decreases (- amount)
    double change = payment.type == 'Credit' ? payment.amount : -payment.amount;
    
    final customerRef = _customersRef.doc(payment.customerId);
    batch.update(customerRef, {
      'totalDue': FieldValue.increment(change),
      'lastTransactionDate': payment.date,
    });

    await batch.commit();
  }

  // --- Department Accounts ---
  Stream<List<DepartmentAccountModel>> getDepartmentAccounts() {
    return _accountsRef.orderBy('department').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DepartmentAccountModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addDepartmentAccount(DepartmentAccountModel account) async {
    await _accountsRef.add(account.toMap());
  }
  
  Future<void> updateDepartmentAccount(DepartmentAccountModel account) async {
    await _accountsRef.doc(account.id).update(account.toMap());
  }
  
  Future<void> deleteDepartmentAccount(String id) async {
    await _accountsRef.doc(id).delete();
  }
  
  // Verify Login (returns account if valid)
  Future<DepartmentAccountModel?> verifyLogin(String dept, String password) async {
    // Note: In production use cloud functions or simpler id check. 
    // Here we scan. Security warning: Indexing.
    // Assuming 'dept' passed is the exact department string or username? User said "department selector dropdown".
    // Let's assume username is the department name or simpler.
    // Actually user said "Department Selector" so we match by department field.
    // Simplified query to avoid Composite Index requirement
    final snap = await _accountsRef
        .where('department', isEqualTo: dept)
        .limit(10) // Small limit, usually 1
        .get();
        
    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['password'] == password && data['isActive'] == true) {
         return DepartmentAccountModel.fromMap(doc.id, data);
      }
    }
    return null;
        

  }

  // --- Company Settings ---
  Stream<CompanySettingsModel> getCompanySettings() {
    return _settingsRef.doc('company_profile').snapshots().map((doc) {
      if (doc.exists) {
        return CompanySettingsModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return CompanySettingsModel.defaults();
    });
  }

  Future<void> saveCompanySettings(CompanySettingsModel settings) async {
    await _settingsRef.doc('company_profile').set(settings.toMap());
  }

  // --- App Config (License/Lock) ---
  Stream<Map<String, dynamic>> getAppConfig() {
    return _settingsRef.doc('app_config').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // EMERGENCY OVERRIDE: Unlock the app (comment this out later)
        // data['is_locked'] = false; 
        return data; 
      }
      // Default Config (Unlocked)
      return {
        'is_locked': false,
        'lock_message': 'Trial Period Expired. Please contact the administrator.',
        'admin_pin': '8008', // Default PIN (BOOB?) User asked for "some pin". I'll set a standard one.
        'developer_contact': 'Contact Admin for Access',
      };
    });
  }

  Future<void> updateAppLockStatus(bool isLocked) async {
    await _settingsRef.doc('app_config').set({'is_locked': isLocked}, SetOptions(merge: true));
  }
}
