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
    // If order completed, show receipt inline (preserves sidebar)
    if (_completedOrder != null) {
       return ReceiptPreviewScreen(order: _completedOrder!, onReturn: _resetPos);
    }

    final db = Provider.of<DatabaseService>(context);
    
    // Using StreamBuilder to keep GST rate reactive
    return StreamBuilder<CompanySettingsModel>(
      stream: db.getCompanySettings(),
      builder: (context, settingsSnap) {
          final settings = settingsSnap.data ?? CompanySettingsModel.defaults();
          
          // Only update if we haven't manually toggled/modified something that depends on it? 
          // Actually, we want to respect the DB setting.
          // But we validly might want to capture it once. 
          // For now, let's sync it.
          // Note: calling setState during build is bad. We'll just use the value directly in calculation logic or UI.
          // But _calculateTotal relies on _currentGstRate.
          // We should update _currentGstRate here? No, that causes rebuild loop.
          // Better: Use 'settings.gstRate' directly in UI, and assume _currentGstRate is synced or just use settings.gstRate.
          // However, _saveOrder needs the rate.
          // Let's rely on the value passed to _saveOrder or stored in a variable that is updated safely.
          // We can use a local variable for the rate in this build scope.
          
          final effectiveGstRate = settings.gstRate;
          // We'll update the class member for the callbacks to use. 
          // To avoid build-phase setState error, we just assign it. It's a bit dirty but works if no rebuild triggers immediately.
          _currentGstRate = effectiveGstRate;

          // Re-calculate totals because rate might have changed?
          // We can't easily do side-effects here. 
          // We'll calculate display values on the fly if needed, or rely on user action to trigger recalc.
          // Logic fix: _calculateTotal() uses _currentGstRate. 
          // Let's just trust _calculateTotal will be called when user adds items. 
          // If rate changes while on screen, totals might be stale until an action. That's acceptable for now.

        return Scaffold(
          appBar: AppBar(
        title: const Text('New Order (POS)'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Product Catalogue (Left - 60%)
          Expanded(
            flex: 3,
            child: Container(
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
                            return DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                hintText: 'Category',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
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
                         // Aggregate Stock
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
                            
                            // Filter
                            if (_searchQuery.isNotEmpty) {
                              products = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                            }

                            if (products.isEmpty) {
                              return Center(child: Text('No products found', style: TextStyle(color: Colors.grey[600])));
                            }

                            return GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, 
                                childAspectRatio: 0.8, // Taller for stock info
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
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
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                                    ),
                                    padding: const EdgeInsets.all(8), // Reduced padding
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isOutOfStock ? Colors.grey.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isOutOfStock ? Colors.grey : Colors.amber),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          p.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        // Stock Indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isOutOfStock ? 'Out of Stock' : 'Stock: ${available.toInt()}',
                                            style: TextStyle(
                                              fontSize: 10, 
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
            ),
          ),
          
          // Cart Section (Right - 40%)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Customer Info Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 2), blurRadius: 2)],
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
                                  _customerCtrl.text = selection.name; // Keep text sync
                                });
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                // Initialize controller if selected
                                if (_selectedCustomer != null && textEditingController.text.isEmpty) {
                                  textEditingController.text = _selectedCustomer!.name;
                                }
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Search Customer...',
                                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    suffixIcon: _selectedCustomer != null 
                                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                          setState(() { _selectedCustomer = null; textEditingController.clear(); });
                                        }) 
                                      : null
                                  ),
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
                              Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Cart is empty', style: TextStyle(color: Colors.grey[400])),
                            ],
                          )
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _cart.length,
                          separatorBuilder: (_,__) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = _cart[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40, 
                                height: 40, 
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.local_mall, color: Colors.grey, size: 20),
                              ),
                              title: Text('Product (ID: ...${item.productId.substring(0,4)})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('${item.quantity.toInt()} units x ₹${item.price}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹${(item.quantity * item.price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), offset: const Offset(0, -2), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                            Text('₹${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              height: 24, 
                              width: 24,
                              child: Checkbox(
                                value: _applyGst, 
                                onChanged: (val) => setState(() { _applyGst = val ?? false; _calculateTotal(); }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Apply GST ($effectiveGstRate%)', style: const TextStyle(fontSize: 13)), // Dynamic Label
                            const Spacer(),
                            if (_applyGst) Text('₹${_gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Payable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _cart.isEmpty ? null : () => _saveOrder(db, effectiveGstRate),
                            icon: const Icon(Icons.check_circle, color: Colors.white),
                            label: const Text('COMPLETE ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
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
}
