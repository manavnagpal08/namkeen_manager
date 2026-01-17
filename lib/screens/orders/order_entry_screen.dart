import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/warehouse_stock_model.dart';
import '../../models/company_settings_model.dart'; // Added missing import
import '../../models/category_model.dart'; // Added
import '../../services/database_service.dart';
import 'receipt_preview_screen.dart';
import '../../models/customer_model.dart';

class OrderEntryScreen extends StatefulWidget {
  const OrderEntryScreen({super.key});

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  final _customerCtrl = TextEditingController();
  final List<OrderItem> _cart = [];
  
  double _totalAmount = 0;
  double _subTotal = 0;
  double _gstAmount = 0;
  bool _applyGst = false;

  String _searchQuery = '';
  String? _selectedCategory; // Added
  CustomerModel? _selectedCustomer; // Added
  double _currentGstRate = 12.0;

  // New: Track completion for inline navigation
  OrderModel? _completedOrder;

  void _resetPos() {
    setState(() {
      _completedOrder = null;
      _cart.clear();
      _customerCtrl.clear();
      _selectedCustomer = null;
      _searchQuery = '';
      _totalAmount = 0;
      _subTotal = 0;
      _gstAmount = 0;
      _applyGst = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('OrderEntryScreen: Building. CompletedOrder=${_completedOrder != null}');
    final db = Provider.of<DatabaseService>(context);
    return StreamBuilder<CompanySettingsModel>(
      stream: db.getCompanySettings(),
      builder: (context, settingsSnap) {
          final settings = settingsSnap.data ?? CompanySettingsModel.defaults();
          final effectiveGstRate = settings.gstRate;
          _currentGstRate = effectiveGstRate;

          // If order completed, show receipt inline (preserves sidebar)
          if (_completedOrder != null) {
             return ReceiptPreviewScreen(
               order: _completedOrder!, 
               settings: settings, 
               onReturn: _resetPos
             );
          }

        final size = MediaQuery.of(context).size;
        final bool isMobile = size.width < 900;

        Widget mainContent = isMobile 
          ? TabBarView(
              children: [
                _buildCatalogue(db, isMobile),
                _buildCart(db, effectiveGstRate),
              ],
            )
          : Row(
              children: [
                // Product Catalogue (Left - 60%)
                Expanded(
                  flex: 3,
                  child: _buildCatalogue(db, isMobile),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                // Cart Section (Right - 40%)
                Expanded(
                  flex: 2,
                  child: _buildCart(db, effectiveGstRate),
                ),
              ],
            );

        Widget scaffold = Scaffold(
          appBar: AppBar(
            title: const Text('New Order (POS)'),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (!isMobile)
                IconButton(
                  onPressed: _resetPos,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Order',
                ),
              const SizedBox(width: 8),
            ],
            bottom: isMobile ? TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withAlpha(180),
              tabs: [
                const Tab(text: 'Catalogue', icon: Icon(Icons.dashboard_outlined)),
                Tab(
                  icon: Badge(
                    label: Text(_cart.length.toString()),
                    isLabelVisible: _cart.isNotEmpty,
                    backgroundColor: Colors.amber,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  text: 'Cart',
                ),
              ],
            ) : null,
          ),
          body: mainContent,
        );

        return isMobile ? DefaultTabController(length: 2, child: scaffold) : scaffold;
      },
    );
  }

  Widget _buildCatalogue(DatabaseService db, bool isMobile) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Category Filter & Search
          Row(
            children: [
              Expanded(
                flex: 1,
                child: StreamBuilder<List<CategoryModel>>(
                  stream: db.getCategories(),
                  builder: (context, catSnap) {
                    final categories = catSnap.data ?? [];
                    return DropdownButtonFormField<String?>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        hintText: 'Category',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All')),
                        ...categories.map<DropdownMenuItem<String?>>((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Grid
          Expanded(
            child: StreamBuilder<List<WarehouseStockModel>>(
              stream: db.getWarehouseStock(),
              builder: (context, stockSnap) {
                 final stocks = stockSnap.data ?? [];
                 final Map<String, double> stockMap = {};
                 for (var s in stocks) {
                   stockMap[s.productId] = (stockMap[s.productId] ?? 0) + s.quantityPackets;
                 }

                 return StreamBuilder<List<ProductModel>>(
                  stream: db.getProducts(categoryId: _selectedCategory),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    var products = snapshot.data ?? [];
                    
                    if (_searchQuery.isNotEmpty) {
                      products = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                    }

                    if (products.isEmpty) {
                      return Center(child: Text('No products found', style: TextStyle(color: Colors.grey[600])));
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 3 : (MediaQuery.of(context).size.width > 1200 ? 4 : 3), 
                        childAspectRatio: 0.82, 
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final available = stockMap[p.id] ?? 0;
                        final isOutOfStock = available <= 0;

                        return InkWell(
                          onTap: isOutOfStock ? null : () => _addToCart(context, db, p, available),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4)],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isOutOfStock ? Colors.grey.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOutOfStock ? Colors.grey : Colors.amber),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  p.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOutOfStock ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isOutOfStock ? 'Out' : 'Stock: ${available.toInt()}',
                                    style: TextStyle(
                                      fontSize: 9, 
                                      fontWeight: FontWeight.bold,
                                      color: isOutOfStock ? Colors.red : Colors.green
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

  Widget _buildCart(DatabaseService db, double effectiveGstRate) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Customer Info Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), offset: const Offset(0, 2), blurRadius: 2)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    if (_selectedCustomer != null)
                      Text('Due: ₹${_selectedCustomer!.totalDue.toStringAsFixed(0)}', style: TextStyle(color: _selectedCustomer!.totalDue > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<CustomerModel>>(
                  stream: db.getCustomers(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? [];
                    
                    return Autocomplete<CustomerModel>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<CustomerModel>.empty();
                        }
                        return customers.where((CustomerModel option) {
                          return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                 option.phone.contains(textEditingValue.text);
                        });
                      },
                      displayStringForOption: (CustomerModel option) => option.name,
                      onSelected: (CustomerModel selection) {
                        setState(() {
                          _selectedCustomer = selection;
                          _customerCtrl.text = selection.name;
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        if (_selectedCustomer != null && textEditingController.text.isEmpty) {
                          textEditingController.text = _selectedCustomer!.name;
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search Customer...',
                                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  suffixIcon: _selectedCustomer != null 
                                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                                        setState(() { _selectedCustomer = null; textEditingController.clear(); });
                                      }) 
                                    : null
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: IconButton(
                                icon: const Icon(Icons.person_add, color: AppTheme.primary, size: 20),
                                tooltip: 'Add New Customer',
                                onPressed: () => _showAddCustomerDialog(context),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Cart Items
          Expanded(
            child: _cart.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[200]),
                      const SizedBox(height: 16),
                      Text('Cart is empty', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  )
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cart.length,
                  separatorBuilder: (_,__) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 44, 
                        height: 44, 
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.local_mall_outlined, color: AppTheme.primary, size: 22),
                      ),
                      title: Text(item.productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantity.toInt()} units × ₹${item.price}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${(item.quantity * item.price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() {
                                _cart.removeAt(index);
                                _calculateTotal();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),

          // Totals Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), offset: const Offset(0, -4), blurRadius: 12)],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    Text('₹${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 24, 
                      width: 24,
                      child: Checkbox(
                        value: _applyGst, 
                        activeColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) => setState(() { _applyGst = val ?? false; _calculateTotal(); }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Apply GST ($effectiveGstRate%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (_applyGst) Text('₹${_gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _cart.isEmpty ? null : () => _saveOrder(db, effectiveGstRate),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 20),
                        SizedBox(width: 10),
                        Text('COMPLETE ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Logic Helpers - MOVED OUTSIDE BUILD
  void _addToCart(BuildContext context, DatabaseService db, ProductModel product, double availableStock) {
    if (product.id.isEmpty) {
        // Should not happen, but safe check
        return;
    }

    final qtyCtrl = TextEditingController(text: '1');
    String sizeId = product.defaultSizeId;
    final double defaultPrice = product.sizePrices[sizeId] ?? 0.0;
    final priceCtrl = TextEditingController(text: defaultPrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Add ${product.name}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text('Available Stock: ${availableStock.toInt()}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
             const SizedBox(height: 12),
             TextField(
               controller: qtyCtrl, 
               keyboardType: TextInputType.number, 
               autofocus: true,
               decoration: const InputDecoration(labelText: 'Quantity (Packets)', border: OutlineInputBorder()),
             ),
             const SizedBox(height: 12),
             TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price per Unit (₹)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text) ?? 1;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              
              if (qty > availableStock) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient Stock!'), backgroundColor: Colors.red));
                 return;
              }

              setState(() {
                _cart.add(OrderItem(
                  productId: product.id, 
                  productName: product.name,
                  sizeId: sizeId, 
                  sizeName: sizeId, // Using ID as name for now until we fetch size map
                  quantity: qty, 
                  price: price
                ));
                _calculateTotal();
              });
              Navigator.pop(context);
            },
            child: const Text('Add to Cart'),
          )
        ],
      ),
    );
  }

  void _calculateTotal() {
    double t = 0;
    for (var i in _cart) {
      t += (i.quantity * i.price);
    }
    _subTotal = t;
    _gstAmount = _applyGst ? _subTotal * (_currentGstRate / 100.0) : 0;
    _totalAmount = _subTotal + _gstAmount;
  }
  
  Future<void> _saveOrder(DatabaseService db, double currentGstRate) async {
    if (_cart.isEmpty) return;

    // Validate Stock
    for (var item in _cart) {
      final available = await db.getAvailableStockPackets(item.productId);
      if (item.quantity > available) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('❌ Insufficient Stock for Product (Avail: $available)'), backgroundColor: Colors.red),
           );
        }
        return; 
      }
    }

    try {
      // Deduct Stock
      for (var item in _cart) {
         await db.deductWarehouseStock(item.productId, item.quantity);
      }
  
      final order = OrderModel(
        id: '',
        customerName: _selectedCustomer?.name ?? (_customerCtrl.text.isEmpty ? 'Walk-in' : _customerCtrl.text),
        date: DateTime.now(),
        totalAmount: _totalAmount,
        items: _cart,
        status: _selectedCustomer != null ? 'Credit' : 'Paid', // Credit if linked to customer
        gstPercentage: _applyGst ? currentGstRate : 0.0,
        gstAmount: _gstAmount,
      );
  
      await db.addOrder(order);

      // If Customer -> Add to Ledger (Debt)
      if (_selectedCustomer != null) {
         // Create a synthetic "Order" transaction in ledger
         // We can use the payment model for this, where 'Credit' = Debt Increase
         final ledgerEntry = CustomerPaymentModel(
            id: '', 
            customerId: _selectedCustomer!.id, 
            amount: _totalAmount, 
            type: 'Credit', // Increases Debt
            date: DateTime.now(), 
            notes: 'Order via POS',
            orderId: 'REF-LAST' // Ideally we get ID from addOrder return
         );
         await db.addPayment(ledgerEntry);
      }
      
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Saved & Stock Deducted!')));
        setState(() {
          _completedOrder = order;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving order: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              
              final newCustomer = CustomerModel(
                id: '',
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                address: addressCtrl.text,
                totalDue: 0,
                lastTransactionDate: DateTime.now(),
              );

              await Provider.of<DatabaseService>(context, listen: false).addCustomer(newCustomer);
              if (context.mounted) {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Added! Search to select.')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
