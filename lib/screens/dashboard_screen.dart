import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/namkeen_theme.dart';
import '../core/glass_container.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/stock_service.dart';
import '../models/raw_material_model.dart';
import '../models/batch_model.dart';
import '../models/order_model.dart';
import '../models/warehouse_stock_model.dart';
import 'product_management/manage_attributes_screen.dart';
import 'inventory/inventory_screen.dart';
import 'inventory/warehouse_screen.dart';
import 'analytics/analytics_screen.dart';
import 'customers/customer_list_screen.dart';
import 'package:namkeen_manager/screens/analytics/daily_summary_screen.dart';
import 'product_management/product_list_screen.dart';
import 'employees/employee_list_screen.dart';
import 'production/production_screen.dart';
import 'orders/order_entry_screen.dart';
import 'orders/order_list_screen.dart';
import 'dispatch/dispatch_screen.dart';
import 'dispatch/transfer_screen.dart';
import 'settings/manage_packing_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'settings/department_login_manager.dart';

import 'support_screen.dart';

import '../models/assignment_model.dart'; 
import '../core/responsive_layout.dart';
import '../widgets/weekly_sales_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // For Desktop Rail
  Widget? _currentDesktopPage; 
  
  // Tour Keys
  final GlobalKey _keyStats = GlobalKey();
  final GlobalKey _keyTasks = GlobalKey();
  final GlobalKey _keyActions = GlobalKey();
  bool _tourStarted = false;

  void _checkTour(BuildContext context) async {
    if (_tourStarted) return;
    _tourStarted = true;
    final prefs = await SharedPreferences.getInstance();
    // Force tour for debugging if needed, or check bool
    if (prefs.getBool('seen_dashboard_tour') != true) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
             ShowCaseWidget.of(context).startShowCase([_keyStats, _keyTasks, _keyActions]);
             prefs.setBool('seen_dashboard_tour', true);
          }
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) {
        _checkTour(context);
        return ResponsiveLayout(
          mobileBody: _buildMobileLayout(context),
          desktopBody: _buildDesktopLayout(context),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Factory Manager'),
        backgroundColor: AppTheme.primary.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      drawer: _buildModernDrawer(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.mainGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildDashboardContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    // Desktop Sidebar Layout (Shell)
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar - Wrapped in ScrollView to prevent overflow
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
              child: IntrinsicHeight(
                child: _buildNavigationRail(context),
              ),
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Container(
              color: Colors.grey[50], // Neutral background for content
              child: _currentDesktopPage ?? _buildDesktopHome(context),
            ),
          ),
        ],
      ),
    );
  }

  // Wrapper for the dashboard content to make it look nice on desktop start
  Widget _buildDesktopHome(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.mainGradient),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
             GlassContainer(
                padding: const EdgeInsets.all(24),
                color: Colors.white,
                borderRadius: 16,
                child: Row(
                  children: [
                    const Icon(Icons.factory, size: 40, color: AppTheme.primary),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Factory Manager', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const Text('Desktop Dashboard', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    _SidebarItem(
                  icon: Icons.people, 
                  label: 'Customers', 
                  isSelected: _selectedIndex == 7, 
                  onTap: () => setState(() {
                    _selectedIndex = 7;
                    _currentDesktopPage = const CustomerListScreen();
                  }),
                ),

                const Spacer(),
                    const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.person, color: Colors.white)),
                  ],
                ),
             ),
             const SizedBox(height: 32),
             _buildDashboardContent(context, isDesktop: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, {bool isDesktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) _buildWelcomeHeader(context),
        const SizedBox(height: 24),
        _buildStatGrid(context, isDesktop: isDesktop),
        const SizedBox(height: 30),
        _buildTodayTasks(context),
        const SizedBox(height: 30),
        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final account = auth.currentAccount;
    final role = account?.role ?? user?.role ?? 'Guest';

    // Define all possible items with their role access requirements
    final List<Map<String, dynamic>> allDestinations = [
      {
        'label': 'Home',
        'icon': Icons.dashboard,
        'roles': ['Admin', 'Manager', 'Supervisor', 'Worker', 'Dispatch', 'Guest'],
        'screen': null, // Home
      },
      {
        'label': 'Stock',
        'icon': Icons.inventory,
        'roles': ['Admin', 'Manager', 'Supervisor'],
        'screen': const InventoryScreen(),
      },
      {
        'label': 'Warehouse',
        'icon': Icons.warehouse,
        'roles': ['Admin', 'Manager', 'Supervisor'],
        'screen': const WarehouseScreen(),
      },
      {
        'label': 'Summary',
        'icon': Icons.history,
        'roles': ['Admin', 'Manager', 'Supervisor'],
        'screen': const DailySummaryScreen(),
      },
      {
        'label': 'Analytics',
        'icon': Icons.analytics,
        'roles': ['Admin', 'Manager'],
        'screen': const AnalyticsScreen(),
      },
      {
        'label': 'POS',
        'icon': Icons.point_of_sale,
        'roles': ['Admin', 'Manager'],
        'screen': const OrderEntryScreen(),
      },
      {
        'label': 'Production',
        'icon': Icons.factory,
        'roles': ['Admin', 'Manager', 'Supervisor', 'Worker'],
        'screen': const ProductionScreen(),
      },
      {
        'label': 'Orders',
        'icon': Icons.shopping_cart,
        'roles': ['Admin', 'Manager'],
        'screen': const OrderListScreen(),
      },
      {
        'label': 'Dispatch',
        'icon': Icons.local_shipping,
        'roles': ['Admin', 'Manager', 'Dispatch'],
        'screen': const DispatchScreen(),
      },
      {
        'label': 'Transfer',
        'icon': Icons.compare_arrows,
        'roles': ['Admin', 'Manager', 'Dispatch'],
        'screen': const TransferScreen(),
      },
      {
        'label': 'Settings',
        'icon': Icons.settings_applications,
        'roles': ['Admin'],
        'screen': const AdminSettingsScreen(),
      },
       {
        'label': 'Dept Login',
        'icon': Icons.admin_panel_settings,
        'roles': ['Admin'],
        'screen': const DepartmentLoginManager(),
      },
      {
        'label': 'Products',
        'icon': Icons.shopping_bag,
        'roles': ['Admin', 'Manager'],
        'screen': const ProductListScreen(),
      },
      {
        'label': 'Attributes',
        'icon': Icons.category,
        'roles': ['Admin', 'Manager'],
        'screen': const ManageAttributesScreen(),
      },
      {
        'label': 'Pack Config',
        'icon': Icons.settings,
        'roles': ['Admin', 'Manager'],
        'screen': const ManagePackingScreen(),
      },
      {
        'label': 'Employees',
        'icon': Icons.people,
        'roles': ['Admin', 'Manager'],
        'screen': const EmployeeListScreen(),
      },
      {
        'label': 'Support',
        'icon': Icons.help_outline,
        'roles': ['Admin', 'Manager', 'Supervisor', 'Worker', 'Dispatch', 'Guest'],
        'screen': const SupportScreen(),
      },
    ];

    // Filter based on current user role
    final visibleItems = allDestinations.where((item) {
      final List<String> allowed = item['roles'] as List<String>;
      return allowed.contains(role);
    }).toList();

    // Safe index handling
    final safeIndex = (_selectedIndex >= visibleItems.length) ? 0 : _selectedIndex;

    return NavigationRail(
      selectedIndex: safeIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
          _currentDesktopPage = visibleItems[index]['screen'] as Widget?;
        });
      },
      backgroundColor: Colors.white,
      labelType: NavigationRailLabelType.all, // Show all labels always
      elevation: 5,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
             IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () => auth.logout()),
          ],
        ),
      ),
      destinations: visibleItems.map((item) {
        return NavigationRailDestination(
          icon: Icon(item['icon'] as IconData),
          label: Text(item['label'] as String, style: const TextStyle(fontSize: 10)),
          padding: const EdgeInsets.symmetric(vertical: 8), 
        );
      }).toList(),
      // Add padding at bottom to avoid edge overlap, but Trailing already does that.
      trailing: Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            InkWell(
             onTap: () => setState(() { _currentDesktopPage = const SupportScreen(); _selectedIndex = 99; }),
             child: RotatedBox(
              quarterTurns: -1,
              child: const Text('POWERED BY FLIP CLIP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
             ),
          ),
          const SizedBox(height: 16),
          RotatedBox(
            quarterTurns: -1,
            child: Text(
              role.toUpperCase(), 
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
            ),
          ),
        ],
      ),
    ),
    );
  }

  // --- Helpers reused ---

  Widget _buildWelcomeHeader(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final name = user?.name ?? 'Manager';

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 16,
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $name!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              ),
              const Text(
                'Here is your factory snapshot.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.primary),
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildModernDrawer(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false); 
    final user = auth.currentUser;
    final account = auth.currentAccount;
    final name = account?.departmentName ?? user?.name ?? 'Guest';
    final role = account?.role ?? user?.role ?? 'Guest';
    final id = account?.username ?? user?.id ?? '';

    return Drawer(
      child: Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95)),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  accountEmail: Text('$role • $id', style: const TextStyle(fontSize: 12)),
                  currentAccountPicture: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(name.substring(0, 1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  ),
                  otherAccountsPictures: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () {
                        auth.logout();
                        Navigator.pushReplacementNamed(context, '/'); 
                      },
                    )
                  ],
                ),
                
                _drawerItem(context, Icons.dashboard, 'Dashboard', null),

                if (role == 'Admin' || role == 'Manager' || role == 'Supervisor') ...[
                  _drawerItem(context, Icons.inventory, 'Raw Material', const InventoryScreen()),
                  _drawerItem(context, Icons.warehouse, 'Warehouse (Finished)', const WarehouseScreen()),
                  _drawerItem(context, Icons.history, 'Daily Summary', const DailySummaryScreen()),
                ],
                
                if (role == 'Admin' || role == 'Manager') ...[
                   _drawerItem(context, Icons.analytics, 'Poll Analytics', const AnalyticsScreen(), color: Colors.purple),
                   if (role == 'Admin') ...[
                     const Divider(),
                     _drawerItem(context, Icons.settings_applications, 'Admin Settings', const AdminSettingsScreen()),
                     _drawerItem(context, Icons.admin_panel_settings, 'Dept Login Manager', const DepartmentLoginManager()), 
                   ],
                   const Divider(),
                   _drawerItem(context, Icons.shopping_bag, 'Products & Recipes', const ProductListScreen()),
                   _drawerItem(context, Icons.category, 'Attributes', const ManageAttributesScreen()),
                   _drawerItem(context, Icons.settings, 'Pack Config', const ManagePackingScreen()),
                   _drawerItem(context, Icons.people, 'Employees', const EmployeeListScreen()),
                   const Divider(),
                ],

                if (role == 'Admin' || role == 'Manager' || role == 'Supervisor' || role == 'Worker') ...[
                   _drawerItem(context, Icons.factory, 'Production Batches', const ProductionScreen()),
                ],
                if (role == 'Admin' || role == 'Manager') ...[
                   _drawerItem(context, Icons.point_of_sale, 'New Order (POS)', const OrderEntryScreen()),
                ],

                if (role == 'Admin' || role == 'Manager' || role == 'Dispatch') ...[
                   _drawerItem(context, Icons.local_shipping, 'Dispatch Logs', const DispatchScreen()),
                   _drawerItem(context, Icons.compare_arrows, 'Material Transfer', const TransferScreen()),
                ],
                
                const Divider(),
                _drawerItem(context, Icons.people_alt, 'Customer Ledger', const CustomerListScreen()),
                _drawerItem(context, Icons.verified, 'Support & Updates', const SupportScreen(), color: AppTheme.primary),
              ],
            ),
          ),
          // Footer Pinned to Bottom
          const Divider(height: 1),
          ListTile(
            title: const Center(child: Text('Powered by FLIP CLIP', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, Widget? screen, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textSecondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildStatGrid(BuildContext context, {bool isDesktop = false}) {
    final db = Provider.of<DatabaseService>(context, listen: false);

    return Showcase(
      key: _keyStats,
      title: 'Factory Overview',
      description: 'Track Raw Material, Active Batches, and Warehouse Stock at a glance.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sales Chart Section (Premium Look)
          StreamBuilder<List<OrderModel>>(
            stream: db.getOrdersStream(),
            builder: (context, snapshot) {
               final orders = snapshot.data ?? [];
               // Calc total sales today
               final today = DateTime.now();
               final todaySales = orders.where((o) => 
                 o.date.year == today.year && o.date.month == today.month && o.date.day == today.day
               ).fold(0.0, (sum, o) => sum + o.totalAmount);

               return GlassContainer(
                 padding: const EdgeInsets.all(20),
                 borderRadius: 24,
                 // gradient: removed for white theme
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('Weekly Sales Trend', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                             const SizedBox(height: 4),
                             Text('₹${todaySales.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
                             const Text('Today\'s Revenue', style: TextStyle(color: Colors.grey, fontSize: 10)),
                           ],
                         ),
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                           child: const Icon(Icons.trending_up, color: AppTheme.primary),
                         )
                       ],
                     ),
                     const SizedBox(height: 20),
                     const SizedBox(height: 20),
                     SizedBox(
                       height: 250, // Fixed height to keep it small
                       child: WeeklySalesChart(orders: orders),
                     ),
                   ],
                 ),
               );
            },
          ),
          
          const SizedBox(height: 16),

          // 2. Stats Grid
          GridView.count(
          crossAxisCount: isDesktop ? 4 : 2, 
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1, // Slightly taller
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StreamBuilder<List<RawMaterialModel>>(
              stream: db.getRawMaterials(),
              builder: (context, snapshot) {
                final count = snapshot.data?.where((i) => i.currentStock <= i.minimumThreshold).length ?? 0;
                return InkWell(
                  onTap: () => _navigateToDesktopPage(const InventoryScreen()),
                  child: _buildStatCard('Low Stock', '$count Alerts', Colors.red, Icons.warning_amber_rounded, isLoading: snapshot.connectionState == ConnectionState.waiting),
                );
              },
            ),
            StreamBuilder<List<BatchModel>>(
              stream: db.getBatches(),
              builder: (context, snapshot) {
                 final count = snapshot.data?.where((b) => b.status == 'In Progress').length ?? 0;
                 return InkWell(
                   onTap: () => _navigateToDesktopPage(const ProductionScreen()),
                   child: _buildStatCard('Production', '$count Batches', Colors.orange, Icons.whatshot, isLoading: snapshot.connectionState == ConnectionState.waiting),
                 );
              },
            ),
            StreamBuilder<List<OrderModel>>(
              stream: db.getOrders(),
              builder: (context, snapshot) {
                 final count = snapshot.data?.where((o) => o.status != 'Completed' && o.status != 'Cancelled').length ?? 0; 
                 return InkWell(
                   onTap: () => _navigateToDesktopPage(const OrderListScreen()),
                   child: _buildStatCard('Pending Orders', '$count Active', Colors.blue, Icons.shopping_cart, isLoading: snapshot.connectionState == ConnectionState.waiting),
                 );
              },
            ),
             StreamBuilder<List<WarehouseStockModel>>(
              stream: db.getWarehouseStock(),
              builder: (context, snapshot) {
                 // Sum total packets
                 final total = snapshot.data?.fold(0.0, (sum, item) => sum + item.quantityPackets) ?? 0;
                 return InkWell(
                   onTap: () => _navigateToDesktopPage(const WarehouseScreen()),
                   child: _buildStatCard('Warehouse', '${total.toStringAsFixed(0)} Pkts', Colors.green, Icons.inventory_2, isLoading: snapshot.connectionState == ConnectionState.waiting),
                 );
              },
            ),
          ],
        ),
        ],
      ),
    );
  }
  
  // Helper to switch pages on desktop regardless of context
  void _navigateToDesktopPage(Widget page) {
    if (MediaQuery.of(context).size.width > 900) {
      setState(() {
        _currentDesktopPage = page;
        // Also update index if possible? Hard to map back to index without searching. 
        // We'll leave index as is or reset to -1 if custom.
      });
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, {bool isLoading = false}) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      gradient: LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight
      ),
      child: isLoading 
        ? Center(child: CircularProgressIndicator(color: color)) 
        : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final role = auth.currentAccount?.role ?? auth.currentUser?.role ?? 'Guest';

    return Showcase(
      key: _keyActions,
      title: 'Quick Actions',
      description: 'Instant access to create Orders, assign Batches, and manage Dispatch.',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (role == 'Admin' || role == 'Manager' || role == 'Supervisor') 
              _actionButton(context, Icons.add, 'New Batch', AppTheme.primary, () => _navigateToDesktopPage(const ProductionScreen())),
            
            if (role == 'Admin' || role == 'Manager') 
              _actionButton(context, Icons.shopping_cart, 'New Order', Colors.green, () => _navigateToDesktopPage(const OrderEntryScreen())),
            
            if (role == 'Admin' || role == 'Manager') 
              _actionButton(context, Icons.settings, 'Attributes', Colors.blueGrey, () => _navigateToDesktopPage(const ManageAttributesScreen())),

            if (role == 'Admin' || role == 'Manager' || role == 'Supervisor') ...[
               _actionButton(context, Icons.build, 'Manufacturing', Colors.orange, () => _navigateToDesktopPage(const ProductionScreen())),
               _actionButton(context, Icons.inventory_2, 'Packaging', Colors.brown, () => _navigateToDesktopPage(const ProductionScreen())),
            ],

            if (role == 'Worker' || role == 'Supervisor')
               _actionButton(context, Icons.task_alt, 'My Tasks', Colors.teal, () => _navigateToDesktopPage(const ProductionScreen())), 
            
            if (role == 'Dispatch')
               _actionButton(context, Icons.local_shipping, 'Dispatch', Colors.indigo, () => _navigateToDesktopPage(const DispatchScreen())),
          ],
        ),
        const SizedBox(height: 24),
        
      ],
    ),
    );
  }
  
  Widget _actionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: Colors.white,
        borderRadius: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTasks(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final today = DateTime.now();

    return Showcase(
      key: _keyTasks,
      title: 'Daily Tasks',
      description: 'View and manage all manufacturing & packaging jobs assigned for today.',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Task Definer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<List<AssignmentModel>>(
          stream: db.getAssignments(), 
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final allTasks = snapshot.data ?? [];
            final todaysTasks = allTasks.where((task) {
              final d = task.assignedAt; 
              return d.year == today.year && 
                      d.month == today.month && 
                      d.day == today.day &&
                      task.status != 'Completed';
            }).toList();

            if (todaysTasks.isEmpty) {
              return GlassContainer(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                borderRadius: 16,
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green),
                    SizedBox(width: 12),
                    Text('No pending tasks for today!'),
                  ],
                ),
              );
            }

            // Fetch Batches for Name Resolution
            return StreamBuilder<List<BatchModel>>(
              stream: db.getBatches(),
              builder: (context, batchSnap) {
                 final batches = batchSnap.data ?? [];
                 final batchMap = {for (var b in batches) b.id: b.batchCode};

                 return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todaysTasks.length,
                  itemBuilder: (context, index) {
                    final task = todaysTasks[index];
                    final bCode = batchMap[task.batchId] ?? task.batchId;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: task.type == 'Manufacturing' ? Colors.orange.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                          child: Icon(
                            task.type == 'Manufacturing' ? Icons.whatshot : Icons.inventory_2,
                            color: task.type == 'Manufacturing' ? Colors.orange : Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text('${task.type} (Batch: $bCode)'),
                        subtitle: Text('Target: ${task.targetQuantity} • Status: ${task.status}'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => _showCompleteTaskDialog(context, task),
                      ),
                    );
                  },
                );
              }
            );
          },
        ),
      ],
    ),
    );
  }

  Future<void> _showCompleteTaskDialog(BuildContext context, AssignmentModel task) async {
    final qtyCtrl = TextEditingController(text: task.targetQuantity.toString());
    final db = Provider.of<DatabaseService>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete ${task.type}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark this task as completed?', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual Quantity', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Close dialog first to prevent lag appearance
              
              try {
                // 1. Update Assignment
                final completedTask = task.copyWith(
                  status: 'Completed',
                  completedAt: DateTime.now(),
                  completedUnits: double.tryParse(qtyCtrl.text) ?? task.targetQuantity,
                );
                await db.updateAssignment(completedTask);

                // 2. Handle Logic Chain
                if (task.type == 'Manufacturing') {
                    // Update Batch Status to 'Ready for Packing'
                    // Find batch first - (Inefficient for now but works)
                    final batches = await db.getBatches().first;
                    final batch = batches.firstWhere((b) => b.id == task.batchId, orElse: () => BatchModel(id: '', batchCode: '', productId: '', recipeId: '', sizeId: '', targetQuantityKg: 0, status: '', startTime: DateTime.now(), supervisorId: ''));
                    
                    if (batch.id.isNotEmpty) {
                       await db.updateBatch(batch.copyWith(status: 'Ready for Packing'));
                       if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manufacturing Done! Batch is now Ready for Packing.')));
                       }
                       // Deduct raw materials
                       final stockService = StockService();
                       await stockService.deductRawMaterialsForBatch(batch, actualProducedKg: completedTask.completedUnits, usedMaterials: task.materialsUsed);
                    }
                } else if (task.type == 'Packaging') {
                    // Update Stock
                    final stockService = StockService();
                    // Fetch config for this batch size
                    // Since specific config isn't stored on assignment, we fetch standard for batch size
                    // We assume standard packing config for now.
                    final batches = await db.getBatches().first;
                    final batch = batches.firstWhere((b) => b.id == task.batchId);
                    
                    if (batch.id.isNotEmpty) {
                       final config = await db.getPackingConfigForSize(batch.sizeId);
                       await stockService.processPackagingCompletion(completedTask, config);
                       
                       // Also update batch status if this was the last step
                       await db.updateBatch(batch.copyWith(status: 'Packaged'));
                       
                       if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Packaging Done! Stock added to Warehouse.')));
                       }
                    }
                }

              } catch (e) {
                 debugPrint("Error completing task: $e");
                 if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Confirm Completion'),
          ),
        ],
      ),
    );
  }
}
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
