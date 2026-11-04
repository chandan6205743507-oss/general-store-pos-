import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'bill_screen.dart';
import 'shop_screen.dart';
import 'sales_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirana POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<ProductItem> _inventory = [];
  List<SaleRecord> _salesHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromStorage();
  }

  Future<void> _loadDataFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final invString = prefs.getString('pos_inventory');
    final salesString = prefs.getString('pos_sales');

    setState(() {
      if (invString != null) {
        final List decoded = jsonDecode(invString);
        _inventory = decoded.map((m) => ProductItem.fromMap(m)).toList();
      } else {
        // Shuruat ke default items
        _inventory = [
          ProductItem(
            id: '1',
            name: 'Good Day Biscuit',
            barcode: '8901030000001',
            price: 10.0,
            costPrice: 8.5,
            stock: 24.0,
            type: ItemType.piece,
          ),
          ProductItem(
            id: '2',
            name: 'Sugar (Chini)',
            barcode: 'L_sugar',
            price: 44.0,
            costPrice: 38.0,
            stock: 50.0,
            type: ItemType.loose,
          ),
        ];
      }

      if (salesString != null) {
        final List decoded = jsonDecode(salesString);
        _salesHistory = decoded.map((m) => SaleRecord.fromMap(m)).toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final invJson = jsonEncode(_inventory.map((i) => i.toMap()).toList());
    await prefs.setString('pos_inventory', invJson);
  }

  Future<void> _saveSales() async {
    final prefs = await SharedPreferences.getInstance();
    final salesJson = jsonEncode(_salesHistory.map((s) => s.toMap()).toList());
    await prefs.setString('pos_sales', salesJson);
  }

  void _handleSaleCompleted(SaleRecord sale) {
    setState(() {
      _salesHistory.insert(0, sale);
      // Stock kam karein
      for (final cartItem in sale.items) {
        final idx = _inventory.indexWhere((p) => p.barcode == cartItem.product.barcode);
        if (idx >= 0) {
          _inventory[idx].stock = (_inventory[idx].stock - cartItem.quantity).clamp(0.0, double.infinity);
        }
      }
    });
    _saveSales();
    _saveInventory();
  }

  void _handleAddProduct(ProductItem item) {
    setState(() {
      _inventory.insert(0, item);
    });
    _saveInventory();
  }

  void _handleUpdateStock(String id, double newStock) {
    setState(() {
      final idx = _inventory.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        _inventory[idx].stock = newStock;
      }
    });
    _saveInventory();
  }

  void _handleMarkPaid(String saleId) {
    setState(() {
      final idx = _salesHistory.indexWhere((s) => s.id == saleId);
      if (idx >= 0) {
        _salesHistory[idx].isPaid = true;
      }
    });
    _saveSales();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final pages = [
      BillScreen(
        inventory: _inventory,
        onSaleCompleted: _handleSaleCompleted,
        onQuickItemAdded: _handleAddProduct,
      ),
      ShopScreen(
        inventory: _inventory,
        onAddProduct: _handleAddProduct,
        onUpdateStock: _handleUpdateStock,
      ),
      SalesScreen(
        salesHistory: _salesHistory,
        onMarkPaid: _handleMarkPaid,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: Colors.teal),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Colors.teal),
            label: 'Shop & Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Colors.teal),
            label: 'Sales Ledger',
          ),
        ],
      ),
    );
  }
}
