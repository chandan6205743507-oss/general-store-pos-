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
      title: 'Vanik POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
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
  List<SaleRecord> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final invString = prefs.getString('pos_inventory');
    final salesString = prefs.getString('pos_sales');

    if (invString != null) {
      final List decoded = jsonDecode(invString);
      _inventory = decoded.map((e) => ProductItem.fromMap(e)).toList();
    } else {
      _inventory = [
        ProductItem(
          id: '1',
          name: 'Good Day Biscuit',
          barcode: '8901063012240',
          price: 10.0,
          costPrice: 8.5,
          stock: 24.0,
          type: ItemType.piece,
        ),
        ProductItem(
          id: '2',
          name: 'Sugar (Chini)',
          barcode: 'L_SUGAR',
          price: 44.0,
          costPrice: 38.0,
          stock: 50.0,
          type: ItemType.loose,
        ),
      ];
    }

    if (salesString != null) {
      final List decodedSales = jsonDecode(salesString);
      _sales = decodedSales.map((e) => SaleRecord.fromMap(e)).toList();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_inventory.map((e) => e.toMap()).toList());
    await prefs.setString('pos_inventory', encoded);
  }

  Future<void> _saveSales() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_sales.map((e) => e.toMap()).toList());
    await prefs.setString('pos_sales', encoded);
  }

  void _onSaleCompleted(SaleRecord sale) {
    setState(() {
      _sales.insert(0, sale);
      for (final cartItem in sale.items) {
        final index = _inventory.indexWhere((p) => p.barcode == cartItem.product.barcode);
        if (index >= 0) {
          _inventory[index].stock -= cartItem.quantity;
          if (_inventory[index].stock < 0) _inventory[index].stock = 0;
        }
      }
    });
    _saveSales();
    _saveInventory();
  }

  void _onAddProduct(ProductItem product) {
    setState(() {
      final existingIndex = _inventory.indexWhere((p) => p.barcode == product.barcode);
      if (existingIndex >= 0) {
        _inventory[existingIndex] = product;
      } else {
        _inventory.add(product);
      }
    });
    _saveInventory();
  }

  void _onUpdateStock(String barcode, double addedStock) {
    setState(() {
      final item = _inventory.firstWhere((p) => p.barcode == barcode);
      item.stock += addedStock;
    });
    _saveInventory();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final screens = [
      BillScreen(
        inventory: _inventory,
        onSaleCompleted: _onSaleCompleted,
        onQuickItemAdded: _onAddProduct,
      ),
      ShopScreen(
        inventory: _inventory,
        onAddProduct: _onAddProduct,
        onUpdateStock: _onUpdateStock,
      ),
      SalesScreen(
        sales: _sales,
        onPaymentStatusChanged: (saleId, isPaid) {
          setState(() {
            final sale = _sales.firstWhere((s) => s.id == saleId);
            sale.isPaid = isPaid;
          });
          _saveSales();
        },
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: Colors.teal.shade100,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Billing'),
          NavigationDestination(icon: Icon(Icons.store), label: 'Shop & Stock'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Sales Ledger'),
        ],
      ),
    );
  }
}
