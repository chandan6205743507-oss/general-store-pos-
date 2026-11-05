import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VanikApp());
}

class VanikApp extends StatelessWidget {
  const VanikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vanik POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9F9F6),
        primaryColor: const Color(0xFF7FA06B),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 1;
  List<ProductItem> _inventory = [];
  List<SaleRecord> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final invData = prefs.getString('v_inv_db');
    final salesData = prefs.getString('v_sales_db');

    if (invData != null) {
      final List decoded = jsonDecode(invData);
      _inventory = decoded.map((e) => ProductItem.fromMap(e)).toList();
    } else {
      _inventory = [
        ProductItem(
          id: '1',
          name: "Haldiram's Punjabi Tadka",
          barcode: '8904063254450',
          sellingPrice: 5.0,
          buyingPrice: 4.0,
          stock: 40.0,
          type: ItemType.piece,
        ),
        ProductItem(
          id: '2',
          name: 'Sugar (Chini)',
          barcode: 'L_CHINI',
          sellingPrice: 44.0,
          buyingPrice: 39.0,
          stock: 50.0,
          type: ItemType.loose,
        ),
      ];
    }

    if (salesData != null) {
      final List decSales = jsonDecode(salesData);
      _sales = decSales.map((e) => SaleRecord.fromMap(e)).toList();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('v_inv_db', jsonEncode(_inventory.map((e) => e.toMap()).toList()));
    await prefs.setString('v_sales_db', jsonEncode(_sales.map((e) => e.toMap()).toList()));
  }

  void _saveProduct(ProductItem item) {
    setState(() {
      final idx = _inventory.indexWhere((p) => p.barcode == item.barcode);
      if (idx >= 0) {
        _inventory[idx] = item;
      } else {
        _inventory.insert(0, item);
      }
    });
    _saveData();
  }

  void _recordSale(SaleRecord sale) {
    setState(() {
      _sales.insert(0, sale);
      for (final cartItem in sale.items) {
        final idx = _inventory.indexWhere((p) => p.barcode == cartItem.product.barcode);
        if (idx >= 0) {
          _inventory[idx].stock -= cartItem.quantity;
          if (_inventory[idx].stock < 0) _inventory[idx].stock = 0;
        }
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7FA06B))));
    }

    final pages = [
      MyShopScreen(inventory: _inventory, onProductUpdated: _saveProduct),
      MakeBillScreen(inventory: _inventory, onSaleSuccess: _recordSale, onProductAddOrUpdate: _saveProduct),
      MySalesScreen(
        sales: _sales,
        pendingCount: _inventory.where((p) => p.isPending).length,
        onPendingTabClicked: () => setState(() => _currentTab = 0),
      ),
    ];

    return Scaffold(
      body: pages[_currentTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        selectedItemColor: const Color(0xFF4A6B35),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'My Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Make Bill'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'My Sales'),
        ],
      ),
    );
  }
}
